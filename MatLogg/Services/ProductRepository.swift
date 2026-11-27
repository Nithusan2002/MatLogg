import Foundation

protocol ProductFavoriteRepository {
    func toggleFavorite(userId: UUID, productId: UUID) async throws
    func isFavorite(userId: UUID, productId: UUID) async throws -> Bool
}

protocol FavoriteListRepository {
    func getFavorites(userId: UUID, kind: ProductKind?) async throws -> [Product]
}

protocol ProductRepository: ProductFavoriteRepository, FavoriteListRepository {
    func saveProduct(_ product: Product, ownerUserId: UUID) async throws
    func cacheCatalogProduct(_ product: Product) async throws
    func getSearchableProducts(ownerUserId: UUID?) async throws -> [Product]
    func getProduct(_ id: UUID) async throws -> Product?
    func getProducts(_ ids: Set<UUID>) async throws -> [UUID: Product]
    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) async throws -> Product?
    func getProductsByBarcodes(_ barcodes: Set<String>, ownerUserId: UUID?) async throws -> [String: Product]
    func saveMatchMapping(_ mapping: ProductMatchMapping) async throws
    func getMatchMapping(for barcode: String) async throws -> ProductMatchMapping?
    func saveScanHistory(userId: UUID, productId: UUID) async throws
    func getRecentScans(userId: UUID, limit: Int) async throws -> [ScanHistory]
    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) async throws -> [Product]
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct]) async throws
    func getMatvaretabellenCache(maxAgeDays: Int) async throws -> [MatvaretabellenProduct]?
}

extension ProductRepository {
    func getProductsByBarcodes(_ barcodes: Set<String>, ownerUserId: UUID?) async throws -> [String: Product] {
        var products: [String: Product] = [:]
        for barcode in barcodes { products[barcode] = try await getProductByBarcode(barcode, ownerUserId: ownerUserId) }
        return products
    }

    func getProducts(_ ids: Set<UUID>) async throws -> [UUID: Product] {
        var products: [UUID: Product] = [:]
        for id in ids { products[id] = try await getProduct(id) }
        return products
    }
}

extension DatabaseService: ProductRepository {}

protocol ProductCatalogService {
    func fetchCommonFoods() async throws -> [MatvaretabellenProduct]
    func searchProducts(query: String) async throws -> [MatvaretabellenProduct]
}

extension MatvaretabellenService: ProductCatalogService {}

protocol BarcodeProductService {
    func searchProductByBarcodeOpenFoodFacts(_ ean: String) async throws -> Product
}

extension APIService: BarcodeProductService {}

nonisolated enum FoodSearchScope: String, Sendable {
    case norway, global
}

protocol ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product]
}

extension ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String) async throws -> [Product] {
        try await searchProductsByNameOpenFoodFacts(query, scope: .norway)
    }
}

extension APIService: ProductNameSearchService {}
