import Foundation
import Testing
@testable import MatLogg

@MainActor
struct FoodPackageMetadataTests {
    @Test(arguments: ["500 ml", "4 x 330 ml", "1,5 l", "", "unknown", "500", "number", "oversized"])
    func optionalQuantityDoesNotAlterNutritionOrCreateServings(quantity: String) async throws {
        var raw: [String: Any] = ["code": "1000000000016", "product_name": "Synthetic drink", "brands": "Example",
            "quantity": quantity, "nutrition_data_per": "100g",
            "nutriments": ["energy-kcal_100g": 42, "proteins_100g": 0, "carbohydrates_100g": 10, "fat_100g": 0]]
        if quantity == "number" { raw["quantity"] = 500 }
        if quantity == "oversized" { raw["quantity"] = String(repeating: "1", count: 120) + " ml" }
        let data = try JSONSerialization.data(withJSONObject: ["products": [raw]])
        let service = APIService(httpClient: PackageMetadataHTTPClient(data: data))
        let product = try #require(try await service.searchProductsByNameOpenFoodFacts("Synthetic").first)
        let expected = ["500 ml", "4 x 330 ml", "1,5 l"].contains(quantity) ? quantity : nil
        #expect(product.packageQuantityLabel == expected)
        #expect(product.amountUnit == .grams)
        #expect(product.caloriesPer100g == 42)
        #expect(product.calculateNutrition(forAmount: 100).calories == 42)
        #expect(product.servings == nil)
        #expect(product.nutritionSource == .openFoodFacts)
    }

    @Test func barcodeIncludesQuantityWithoutUsingServingSizeAsPackage() async throws {
        let raw: [String: Any] = ["code": "1000000000016", "product_name": "Synthetic drink", "quantity": "1 l",
            "serving_size": "250 ml", "nutrition_data_per": "100ml",
            "nutriments": ["energy-kcal_100g": 42, "proteins_100g": 0, "carbohydrates_100g": 10, "fat_100g": 0]]
        let data = try JSONSerialization.data(withJSONObject: ["status": "success", "product": raw])
        let product = try await APIService(httpClient: PackageMetadataHTTPClient(data: data))
            .searchProductByBarcodeOpenFoodFacts("1000000000016")
        #expect(product.packageQuantityLabel == "1 l")
        #expect(product.servings?.contains { $0.kind == .package } != true)
        #expect(product.servings?.first?.grams == 250)
        #expect(product.amountUnit == .milliliters)
    }

    @Test func quantitySurvivesLocalCacheAndOldJSONStillDecodesWithoutIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("package.sqlite"))
        let product = makeProduct(package: "4 x 330 ml")
        try store.cacheCatalogProduct(product)
        #expect(try store.getProduct(product.id)?.packageQuantityLabel == "4 x 330 ml")
        #expect(store.pendingSyncCount() == 0)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(product)) as? [String: Any])
        legacy.removeValue(forKey: "packageQuantityLabel")
        let oldProduct = try JSONDecoder().decode(Product.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(oldProduct.packageQuantityLabel == nil)
        #expect(oldProduct.amountUnit == product.amountUnit)
    }

    @Test func rowsDistinguishPackageGenericAndOwnFoodAndKeepPreparedBasis() {
        let packaged = makeProduct(package: "500 ml", preparation: .prepared)
        let row = FoodSearchRowPresentation(product: packaged)
        #expect(row.identity == "Example · Pakning: 500 ml")
        #expect(row.provenance == "Pakkevare · Open Food Facts")
        #expect(row.brandText == "Example")
        #expect(row.packageText == "Pakning: 500 ml")
        #expect(row.kindTitle == "Pakkevare")
        #expect(row.sourceTitle == "Open Food Facts")
        #expect(row.nutrition.contains("per 100 ml, tilberedt"))
        let generic = Product(name: "Havregryn", source: "matvaretabellen", kind: .genericFood,
            caloriesPer100g: 370, proteinGPer100g: 13, carbsGPer100g: 60, fatGPer100g: 7,
            nutritionSource: .matvaretabellen)
        #expect(FoodSearchRowPresentation(product: generic).provenance == "Generell matvare · Matvaretabellen")
        #expect(FoodSearchRowPresentation(product: generic).identity == nil)
        let own = Product(name: "Egen mat", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
        #expect(FoodSearchRowPresentation(product: own).provenance == "Egen matvare · Brukeroppgitt")
    }

    @Test func onlyExplicitPackageWithDocumentedUnitCanBeUsedAsLegacyFallback() throws {
        let portion = ServingOption(label: "250 ml", grams: 250, unit: .milliliters, source: .openFoodFacts, kind: .portion)
        let package = ServingOption(label: "Hel pakke", grams: 500, unit: .milliliters, source: .openFoodFacts, kind: .package)
        #expect(FoodSearchRowPresentation(product: makeProduct(servings: [portion])).identity == "Example")
        #expect(FoodSearchRowPresentation(product: makeProduct(servings: [portion, package])).identity == "Example · Pakning: 500 ml")
        let heuristic = ServingOption(label: "Hel pakke", grams: 500, source: .heuristic, kind: .package)
        #expect(FoodSearchRowPresentation(product: makeProduct(servings: [heuristic])).identity == "Example")
        var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(package)) as? [String: Any])
        raw.removeValue(forKey: "unit")
        let unspecifiedUnit = try JSONDecoder().decode(ServingOption.self, from: JSONSerialization.data(withJSONObject: raw))
        #expect(FoodSearchRowPresentation(product: makeProduct(servings: [unspecifiedUnit])).identity == "Example")
    }

    private func makeProduct(package: String? = nil, preparation: NutritionPreparation = .asSold,
                             servings: [ServingOption]? = nil) -> Product {
        Product(name: "Synthetic drink", brand: "Example", source: "openfoodfacts",
            caloriesPer100g: 42, proteinGPer100g: 0, carbsGPer100g: 10, fatGPer100g: 0,
            servings: servings, nutritionSource: .openFoodFacts, nutritionBasis: .per100ml,
            nutritionPreparation: preparation, packageQuantityLabel: package)
    }
}

private final class PackageMetadataHTTPClient: HTTPClientProtocol {
    let data: Data
    init(data: Data) { self.data = data }
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let fields = components.queryItems?.first { $0.name == "fields" }?.value?.split(separator: ",")
        #expect(fields?.contains("quantity") == true)
        let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
        return HTTPClientResponse(data: data, response: response)
    }
}
