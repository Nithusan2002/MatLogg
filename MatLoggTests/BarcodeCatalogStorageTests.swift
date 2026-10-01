import Foundation
import Testing
@testable import MatLogg

@MainActor
struct BarcodeCatalogStorageTests {
    @Test func catalogRefreshKeepsHistoricNutritionAndDoesNotQueueProductEvents() throws {
        try withStore { store in
            let owner = UUID()
            let original = product(calories: 100)
            try store.cacheCatalogProduct(original)
            let log = FoodLog(userId: owner, productId: original.id, mealType: "lunsj", amountG: 150,
                              loggedDate: Date(), calories: 150, proteinG: 6, carbsG: 27, fatG: 4.5)
            try store.saveLog(log)
            let events = store.fetchPendingEvents(limit: 20)
            try store.cacheCatalogProduct(product(calories: 200))
            let stored = try #require(store.getAllLogs(userId: owner).first)
            #expect(stored.calories == 150)
            #expect(stored.proteinG == 6)
            #expect(stored.carbsG == 27)
            #expect(stored.fatG == 4.5)
            #expect(stored.resolvedAmountUnit == .grams)
            #expect(store.getProduct(original.id)?.caloriesPer100g == 200)
            #expect(Set(store.fetchPendingEvents(limit: 20).map(\.eventId)) == Set(events.map(\.eventId)))
            #expect(events.allSatisfy { $0.type == "log.upsert" })
        }
    }

    @Test func catalogCannotReplacePrivateRowWithSameIDOrExposeItToAnotherOwner() throws {
        try withStore { store in
            let owner = UUID()
            let own = product(calories: 123, source: .user)
            try store.saveProduct(own, ownerUserId: owner)
            let events = store.fetchPendingEvents(limit: 20)
            #expect(throws: LocalStoreError.self) { try store.cacheCatalogProduct(product(calories: 200)) }
            #expect(store.getProductByBarcode("1234567890123", ownerUserId: owner)?.caloriesPer100g == 123)
            #expect(store.getProductByBarcode("1234567890123", ownerUserId: UUID()) == nil)
            #expect(store.getProductByBarcode("1234567890123", ownerUserId: nil) == nil)
            #expect(Set(store.fetchPendingEvents(limit: 20).map(\.eventId)) == Set(events.map(\.eventId)))
        }
    }

    @Test func privateProductWithSeparateIDWinsOverUpdatedCatalog() throws {
        try withStore { store in
            let owner = UUID()
            let own = Product(name: "Egen vare", barcodeEan: "1234567890123", source: "manual",
                              caloriesPer100g: 123, proteinGPer100g: 4, carbsGPer100g: 18, fatGPer100g: 3)
            try store.saveProduct(own, ownerUserId: owner)
            try store.cacheCatalogProduct(product(calories: 200))
            #expect(store.getProductByBarcode("1234567890123", ownerUserId: owner)?.id == own.id)
            #expect(store.getProductByBarcode("1234567890123", ownerUserId: nil)?.caloriesPer100g == 200)
        }
    }

    private func product(calories: Float, source: NutritionSource = .openFoodFacts) -> Product {
        Product(id: Product.catalogID(source: "openfoodfacts", externalID: "1234567890123"),
                name: "Testvare", barcodeEan: "1234567890123", source: "openfoodfacts",
                caloriesPer100g: calories, proteinGPer100g: 4, carbsGPer100g: 18, fatGPer100g: 3,
                nutritionSource: source, fetchedAt: Date())
    }

    private func withStore(_ body: (LocalStore) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Barcode-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(LocalStore(databaseURL: directory.appendingPathComponent("test.sqlite")))
    }
}
