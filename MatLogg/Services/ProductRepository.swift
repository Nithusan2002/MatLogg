import Foundation

protocol ProductRepository {
    func saveProduct(_ product: Product, ownerUserId: UUID) async throws
    func cacheCatalogProduct(_ product: Product) async throws
    func getSearchableProducts(ownerUserId: UUID?) async throws -> [Product]
    func getProduct(_ id: UUID) -> Product?
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product]
    func getProductByBarcode(_ barcode: String, ownerUserId: UUID?) -> Product?
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
    func searchOwnedProducts(query: String, ownerUserId: UUID) -> [Product]
}

extension ProductRepository {
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        Dictionary(uniqueKeysWithValues: ids.compactMap { id in
            getProduct(id).map { (id, $0) }
        })
    }

    func searchOwnedProducts(query: String, ownerUserId: UUID) -> [Product] { [] }
}

extension DatabaseService: ProductRepository {}

protocol ProductCreationRepository {
    func saveDraft(_ draft: ProductDraft) async throws
    func drafts(ownerUserId: UUID) async -> [ProductDraft]
    func deleteDraft(_ id: UUID, ownerUserId: UUID) async throws
    func completeDraft(_ draft: ProductDraft, product: Product, submission: CatalogSubmission?) async throws
}

extension DatabaseService: ProductCreationRepository {}

struct ClosureProductCreationRepository: ProductCreationRepository {
    let saveDraftAction: (ProductDraft) async throws -> Void
    let draftsAction: (UUID) async -> [ProductDraft]
    let deleteDraftAction: (UUID, UUID) async throws -> Void
    let completeDraftAction: (ProductDraft, Product, CatalogSubmission?) async throws -> Void

    func saveDraft(_ draft: ProductDraft) async throws { try await saveDraftAction(draft) }
    func drafts(ownerUserId: UUID) async -> [ProductDraft] { await draftsAction(ownerUserId) }
    func deleteDraft(_ id: UUID, ownerUserId: UUID) async throws { try await deleteDraftAction(id, ownerUserId) }
    func completeDraft(_ draft: ProductDraft, product: Product, submission: CatalogSubmission?) async throws {
        try await completeDraftAction(draft, product, submission)
    }
}

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

protocol SharedProductCatalogService {
    func searchSharedCatalog(query: String) async throws -> [Product]
}

nonisolated struct UnavailableSharedProductCatalogService: SharedProductCatalogService, Sendable {
    func searchSharedCatalog(query: String) async throws -> [Product] { [] }
}
