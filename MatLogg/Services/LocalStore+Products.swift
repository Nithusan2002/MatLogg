import Foundation

// Read-only domain operations; connection, queue and transactions remain owned by LocalStore.
extension LocalStore {
    func getSearchableProducts(ownerUserId: UUID?) throws -> [Product] {
        try readRows(sql: "SELECT json FROM products WHERE storageKind = 'catalog' OR ownerUserId = ? ORDER BY CASE WHEN storageKind = 'user' THEN 0 ELSE 1 END;", values: [.text(ownerUserId?.uuidString ?? "")]) { try $0.decode(Product.self) }
    }

    func getProduct(_ id: UUID) throws -> Product? {
        try readRows(sql: "SELECT json FROM products WHERE id = ? LIMIT 1;", values: [.text(id.uuidString)]) { try $0.decode(Product.self) }.first
    }

    func getProducts(_ ids: Set<UUID>) throws -> [UUID: Product] {
        guard !ids.isEmpty else { return [:] }
        let ordered = ids.sorted { $0.uuidString < $1.uuidString }
        let queries = stride(from: 0, to: ordered.count, by: 400).map { start in
            let batch = Array(ordered[start..<min(start + 400, ordered.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            return SQLiteReadQuery(sql: "SELECT id, json FROM products WHERE id IN (\(placeholders));", values: batch.map { .text($0.uuidString) })
        }
        let rows = try readRows(queries: queries) { row in
            (try row.uuid(0), try row.decode(Product.self, column: 1))
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) throws -> Product? {
        try readRows(sql: "SELECT json FROM products WHERE barcode = ? AND (storageKind = 'catalog' OR ownerUserId = ?) ORDER BY CASE WHEN ownerUserId = ? THEN 0 ELSE 1 END LIMIT 1;", values: [.text(barcode), .text(ownerUserId?.uuidString ?? ""), .text(ownerUserId?.uuidString ?? "")]) { try $0.decode(Product.self) }.first
    }

    func getProductsByBarcodes(_ barcodes: Set<String>, ownerUserId: UUID?) throws -> [String: Product] {
        let requested = barcodes.sorted()
        let queries = stride(from: 0, to: requested.count, by: 400).map { start in
            let batch = Array(requested[start..<min(start + 400, requested.count)])
            let placeholders = Array(repeating: "?", count: batch.count).joined(separator: ",")
            return SQLiteReadQuery(sql: "SELECT barcode, json FROM products WHERE barcode IN (\(placeholders)) AND (storageKind = 'catalog' OR ownerUserId = ?) ORDER BY CASE WHEN ownerUserId = ? THEN 0 ELSE 1 END;", values: batch.map { .text($0) } + [.text(ownerUserId?.uuidString ?? ""), .text(ownerUserId?.uuidString ?? "")])
        }
        let rows = try readRows(queries: queries) { row in
            (try row.text(0), try row.decode(Product.self, column: 1))
        }
        var result: [String: Product] = [:]
        for (barcode, product) in rows where result[barcode] == nil { result[barcode] = product }
        return result
    }

    func isFavorite(userId: UUID, productId: UUID) throws -> Bool {
        try !readRows(sql: "SELECT id FROM favorites WHERE userId = ? AND productId = ? LIMIT 1;", values: [.text(userId.uuidString), .text(productId.uuidString)]) { try $0.uuid(0) }.isEmpty
    }

    func getFavorites(userId: UUID, kind: ProductKind? = nil) throws -> [Product] {
        let products = try readRows(sql: "SELECT p.json FROM favorites f JOIN products p ON p.id = f.productId WHERE f.userId = ?;", values: [.text(userId.uuidString)]) { try $0.decode(Product.self) }
        return products.filter { kind == nil || $0.kind == kind }
    }

    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) throws -> [Product] {
        guard limit > 0 else { return [] }
        let products = try readRows(sql: "SELECT p.json FROM logs l JOIN products p ON p.id = l.productId WHERE l.userId = ? GROUP BY p.id ORDER BY MAX(l.loggedTime) DESC;", values: [.text(userId.uuidString)]) { try $0.decode(Product.self) }
        return Array(products.filter { kind == nil || $0.kind == kind }.prefix(limit))
    }

    func getMatchMapping(for barcode: String) throws -> ProductMatchMapping? {
        try readRows(sql: "SELECT json FROM match_mappings WHERE barcode = ? LIMIT 1;", values: [.text(barcode)]) { try $0.decode(ProductMatchMapping.self) }.first
    }

    func getMatvaretabellenCache(maxAgeDays: Int) throws -> [MatvaretabellenProduct]? {
        let rows: [[MatvaretabellenProduct]?] = try readRows(sql: "SELECT updatedAt, json FROM matvare_cache WHERE id = 1 LIMIT 1;", values: []) { row in
            let updated = Date(timeIntervalSince1970: try row.number(0))
            guard let age = Calendar.current.dateComponents([.day], from: updated, to: Date()).day,
                  age <= maxAgeDays else { return nil }
            return try row.decode([MatvaretabellenProduct].self, column: 1)
        }
        return rows.first ?? nil
    }
}
