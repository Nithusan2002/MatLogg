import Foundation

protocol ProductRepository {
    func saveProduct(_ product: Product) async throws
    func cacheCatalogProduct(_ product: Product) async throws
    func getProduct(_ id: UUID) -> Product?
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product]
    func getProductByBarcode(_ barcode: String) -> Product?
    func saveMatchMapping(_ mapping: ProductMatchMapping)
    func getMatchMapping(for barcode: String) -> ProductMatchMapping?
    func toggleFavorite(userId: UUID, productId: UUID) async throws
    func isFavorite(userId: UUID, productId: UUID) -> Bool
    func saveScanHistory(userId: UUID, productId: UUID) async throws
    func getRecentScans(userId: UUID, limit: Int) async -> [ScanHistory]
    func getFavorites(userId: UUID, kind: ProductKind?) async -> [Product]
    func getRecentProducts(userId: UUID, kind: ProductKind?, limit: Int) async -> [Product]
    func saveMatvaretabellenCache(_ items: [MatvaretabellenProduct])
    func getMatvaretabellenCache(maxAgeDays: Int) -> [MatvaretabellenProduct]?
}

extension ProductRepository {
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            getProduct(id).map { (id, $0) }
        })
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

protocol ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String) async throws -> [Product]
}

extension APIService: ProductNameSearchService {}
