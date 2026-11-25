import Foundation
import SQLite3
import Testing
@testable import MatLogg

struct DomainReadFailureTests {
    @Test(arguments: ["goals", "weights", "saved_meals", "products", "favorites", "scans", "match_mappings"])
    func missingTableIsAReadError(table: String) throws {
        try withStore { store, url in
            let owner = UUID()
            try execute("DROP TABLE \(table)", at: url)
            switch table {
            case "goals":
                #expect(throws: Error.self) { try store.getLatestGoal(userId: owner) }
            case "weights":
                #expect(throws: Error.self) { try store.getWeightEntries(userId: owner) }
            case "saved_meals":
                #expect(throws: Error.self) { try store.loadSavedMeals(userId: owner) }
            case "products":
                #expect(throws: Error.self) { try store.getProduct(UUID()) }
                #expect(throws: Error.self) { try store.getProducts([UUID()]) }
                #expect(throws: Error.self) { try store.getProductByBarcode("123", ownerUserId: owner) }
                #expect(throws: Error.self) { try store.getProductsByBarcodes(["123"], ownerUserId: owner) }
            case "favorites":
                #expect(throws: Error.self) { try store.getFavorites(userId: owner) }
                #expect(throws: Error.self) { try store.isFavorite(userId: owner, productId: UUID()) }
            case "scans":
                #expect(throws: Error.self) { try store.loadRecentScans(userId: owner, limit: 10) }
            default:
                #expect(throws: Error.self) { try store.getMatchMapping(for: "123") }
            }
        }
    }

    @Test(arguments: ["goals", "weights", "saved_meals"])
    func corruptDomainRowIsNotMissingData(table: String) throws {
        try withStore { store, url in
            let owner = UUID(), id = UUID(), now = Date().timeIntervalSince1970
            let dateColumn = table == "goals" ? "createdDate" : table == "weights" ? "date" : "updatedAt"
            let extraColumns = table == "saved_meals" ? ",name" : ""
            let extraValues = table == "saved_meals" ? ",'QA'" : ""
            try execute("INSERT INTO \(table)(id,userId,\(dateColumn),json\(extraColumns)) VALUES('\(id)','\(owner)',\(now),X'7B'\(extraValues))", at: url)
            switch table {
            case "goals": #expect(throws: Error.self) { try store.getLatestGoal(userId: owner) }
            case "weights": #expect(throws: Error.self) { try store.getWeightEntries(userId: owner) }
            default: #expect(throws: Error.self) { try store.loadSavedMeals(userId: owner) }
            }
        }
    }

    @Test func corruptProductRejectsWholeBatchAndPreservesBothRows() throws {
        try withStore { store, url in
            let valid = Product(name: "QA valid", barcodeEan: "123", source: "off", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
            let corrupt = Product(name: "QA corrupt", barcodeEan: "456", source: "off", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
            try store.cacheCatalogProduct(valid)
            try store.cacheCatalogProduct(corrupt)
            try execute("UPDATE products SET json = X'7B' WHERE id = '\(corrupt.id)'", at: url)
            #expect(throws: LocalStoreError.self) { try store.getProducts([valid.id, corrupt.id]) }
            #expect(throws: LocalStoreError.self) { try store.getProductsByBarcodes(["123", "456"], ownerUserId: nil) }
            #expect(try store.getProduct(valid.id)?.id == valid.id)
            #expect(throws: LocalStoreError.self) { try store.getProduct(corrupt.id) }
        }
    }

    @Test func invalidBindingsAndNumericRowsAreReadErrors() throws {
        try withStore { store, _ in
            #expect(throws: LocalStoreError.self) {
                try store.readRows(sql: "SELECT ?", values: []) { try $0.number(0) }
            }
            #expect(throws: LocalStoreError.self) {
                try store.readRows(sql: "SELECT ?", values: [.number(.nan)]) { try $0.number(0) }
            }
            #expect(throws: LocalStoreError.self) {
                try store.readRows(sql: "SELECT 'invalid'", values: []) { try $0.number(0) }
            }
        }
    }

    @Test func batchesOverParameterLimitReturnAllProductsOrFailTogether() throws {
        try withStore { store, url in
            let products = (0..<405).map { index in
                Product(name: "QA \(index)", barcodeEan: String(format: "qa%04d", index), source: "off", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
            }
            for product in products { try store.cacheCatalogProduct(product) }
            let ids = Set(products.map(\.id))
            let barcodes = Set(products.compactMap(\.barcodeEan))
            #expect(try store.getProducts(ids).count == 405)
            #expect(try store.getProductsByBarcodes(barcodes, ownerUserId: nil).count == 405)
            let last = try #require(products.last)
            try execute("UPDATE products SET json = X'7B' WHERE id = '\(last.id)'", at: url)
            #expect(throws: LocalStoreError.self) { try store.getProducts(ids) }
            #expect(throws: LocalStoreError.self) { try store.getProductsByBarcodes(barcodes, ownerUserId: nil) }
        }
    }

    @Test func corruptCacheIsDistinctFromMissingAndExpiredCache() throws {
        try withStore { store, url in
            #expect(try store.getMatvaretabellenCache(maxAgeDays: 1) == nil)
            try execute("INSERT INTO matvare_cache(id,updatedAt,json) VALUES(1,\(Date().timeIntervalSince1970),X'7B')", at: url)
            #expect(throws: LocalStoreError.self) { try store.getMatvaretabellenCache(maxAgeDays: 1) }
            try execute("UPDATE matvare_cache SET updatedAt=0", at: url)
            #expect(try store.getMatvaretabellenCache(maxAgeDays: 1) == nil)
            try execute("DROP TABLE matvare_cache", at: url)
            #expect(throws: LocalStoreError.self) { try store.getMatvaretabellenCache(maxAgeDays: 1) }
            #expect(throws: LocalStoreError.self) { try store.saveMatvaretabellenCache([]) }
        }
    }

    private func withStore(_ body: (LocalStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("domain-read-qa.sqlite")
        try body(LocalStore(databaseURL: url, healthWritesEnabled: false, diagnosticHandler: { _ in }), url)
    }
    private func execute(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}
