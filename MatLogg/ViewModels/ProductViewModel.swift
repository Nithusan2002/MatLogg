import Foundation
import Combine

@MainActor
final class ProductViewModel: ObservableObject {
    @Published private(set) var errorMessage: String?

    private let repository: any ProductRepository
    private let catalogService: any ProductCatalogService
    private let barcodeService: any BarcodeProductService
    private let matchingService: MatchingService

    init(
        repository: any ProductRepository,
        catalogService: any ProductCatalogService = MatvaretabellenService(),
        barcodeService: any BarcodeProductService = APIService(),
        matchingService: MatchingService = MatchingService()
    ) {
        self.repository = repository
        self.catalogService = catalogService
        self.barcodeService = barcodeService
        self.matchingService = matchingService
    }

    func product(id: UUID) -> Product? {
        repository.getProduct(id)
    }

    func cachedProduct(barcode: String) -> Product? {
        repository.getProductByBarcode(barcode)
    }

    func fetchProduct(barcode: String) async throws -> Product {
        try await barcodeService.searchProductByBarcodeOpenFoodFacts(barcode)
    }

    @discardableResult
    func saveScannedProduct(_ product: Product, userId: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await repository.saveProduct(product)
            try await repository.saveScanHistory(userId: userId, productId: product.id)
            return true
        } catch {
            errorMessage = "Kunne ikke lagre skanning: \(error.localizedDescription)"
            return false
        }
    }

    func recentScans(userId: UUID, limit: Int = 15) async -> [ScanHistory] {
        await repository.getRecentScans(userId: userId, limit: limit)
    }

    func recentProducts(userId: UUID, kind: ProductKind? = nil, limit: Int = 10) async -> [Product] {
        await repository.getRecentProducts(userId: userId, kind: kind, limit: limit)
    }

    func favoriteProducts(userId: UUID, kind: ProductKind? = nil) async -> [Product] {
        await repository.getFavorites(userId: userId, kind: kind)
    }

    @discardableResult
    func toggleFavorite(_ product: Product, userId: UUID) async -> Bool {
        errorMessage = nil
        do {
            try await repository.toggleFavorite(userId: userId, productId: product.id)
            return true
        } catch {
            errorMessage = "Kunne ikke oppdatere favoritt: \(error.localizedDescription)"
            return false
        }
    }

    func isFavorite(_ product: Product, userId: UUID) -> Bool {
        repository.isFavorite(userId: userId, productId: product.id)
    }

    func rawFoodSuggestions() async -> [MatvaretabellenProduct] {
        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 30) {
            return cached
        }
        let items = (try? await catalogService.fetchCommonFoods()) ?? []
        repository.saveMatvaretabellenCache(items)
        return items
    }

    func searchRawFoods(query: String) async -> [MatvaretabellenProduct] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        if let cached = repository.getMatvaretabellenCache(maxAgeDays: 30), !cached.isEmpty {
            let filtered = cached.filter { normalize($0.name).contains(normalize(trimmed)) }
            if !filtered.isEmpty { return filtered }
        }

        let items = (try? await catalogService.searchProducts(query: trimmed)) ?? []
        if items.isEmpty, let cached = repository.getMatvaretabellenCache(maxAgeDays: 30) {
            return cached.filter { normalize($0.name).contains(normalize(trimmed)) }
        }
        return items
    }

    func upgradeNutritionIfPossible(for product: Product) async -> Product? {
        guard let barcode = product.barcodeEan else { return nil }

        if let mapping = repository.getMatchMapping(for: barcode) {
            let daysOld = Calendar.current.dateComponents([.day], from: mapping.updatedAt, to: Date()).day ?? 0
            if daysOld <= 30, mapping.confidenceScore >= 0.85 {
                return await persistUpgrade(makeUpgradedProduct(from: product, mapping: mapping, verified: true))
            }
        }

        let candidates = (try? await catalogService.searchProducts(query: product.name)) ?? []
        guard let best = matchingService.bestMatch(offProduct: product, candidates: candidates) else { return nil }

        let mapping = ProductMatchMapping(
            barcode: barcode,
            matvaretabellenId: best.product.id,
            matchedName: best.product.name,
            confidenceScore: best.score,
            updatedAt: Date(),
            caloriesPer100g: best.product.caloriesPer100g,
            proteinGPer100g: best.product.proteinGPer100g,
            carbsGPer100g: best.product.carbsGPer100g,
            fatGPer100g: best.product.fatGPer100g,
            sugarGPer100g: best.product.sugarGPer100g,
            fiberGPer100g: best.product.fiberGPer100g,
            sodiumMgPer100g: best.product.sodiumMgPer100g,
            category: best.product.category
        )

        if best.score >= 0.85 {
            repository.saveMatchMapping(mapping)
            return await persistUpgrade(makeUpgradedProduct(from: product, mapping: mapping, verified: true))
        }

        if best.score >= 0.60 {
            repository.saveMatchMapping(mapping)
            let suggested = Product(
                id: product.id,
                name: product.name,
                brand: product.brand,
                category: product.category,
                barcodeEan: barcode,
                source: product.source,
                kind: product.kind,
                caloriesPer100g: product.caloriesPer100g,
                proteinGPer100g: product.proteinGPer100g,
                carbsGPer100g: product.carbsGPer100g,
                fatGPer100g: product.fatGPer100g,
                sugarGPer100g: product.sugarGPer100g,
                fiberGPer100g: product.fiberGPer100g,
                sodiumMgPer100g: product.sodiumMgPer100g,
                imageUrl: product.imageUrl,
                standardPortions: product.standardPortions,
                servings: product.servings,
                nutritionSource: product.nutritionSource,
                imageSource: product.imageUrl == nil ? .none : product.imageSource,
                verificationStatus: .suggestedMatch,
                confidenceScore: best.score,
                isVerified: false,
                createdAt: product.createdAt
            )
            return await persistUpgrade(suggested)
        }

        return nil
    }

    private func makeUpgradedProduct(from product: Product, mapping: ProductMatchMapping, verified: Bool) -> Product {
        Product(
            id: product.id,
            name: product.name,
            brand: product.brand,
            category: mapping.category ?? product.category,
            barcodeEan: product.barcodeEan,
            source: product.source,
            kind: product.kind,
            caloriesPer100g: mapping.caloriesPer100g,
            proteinGPer100g: mapping.proteinGPer100g,
            carbsGPer100g: mapping.carbsGPer100g,
            fatGPer100g: mapping.fatGPer100g,
            sugarGPer100g: mapping.sugarGPer100g,
            fiberGPer100g: mapping.fiberGPer100g,
            sodiumMgPer100g: mapping.sodiumMgPer100g,
            imageUrl: product.imageUrl,
            standardPortions: product.standardPortions,
            servings: product.servings,
            nutritionSource: .matvaretabellen,
            imageSource: product.imageUrl == nil ? .none : product.imageSource,
            verificationStatus: verified ? .verified : .suggestedMatch,
            confidenceScore: mapping.confidenceScore,
            isVerified: verified,
            createdAt: product.createdAt
        )
    }

    private func persistUpgrade(_ product: Product) async -> Product {
        do {
            try await repository.saveProduct(product)
        } catch {
            errorMessage = "Kunne ikke lagre forbedrede næringsdata: \(error.localizedDescription)"
        }
        return product
    }

    private func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let allowed = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        let cleaned = String(allowed).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
