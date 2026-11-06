import Foundation
import Testing
import UIKit
@testable import MatLogg

@MainActor
struct FoodGroupTests {
    @Test func sourceCategoriesUseSpecificGroupsAndSafeFallbacks() {
        let cases: [(String, FoodGroup)] = [("5.2", .ricePasta), ("3.8", .meat), ("8.2", .oilFat),
            ("3.1", .poultry), ("1.4.7", .cheese), ("1.1", .dairy), ("5.6.2", .bread),
            ("5.1", .grain), ("6.2", .vegetables), ("13.1", .fruit), ("14.1", .nuts),
            ("9.2", .drinks), ("2", .egg), ("4.1.2", .fish), ("3.7", .other), ("10.9.2", .other), ("99", .other)]
        for (category, group) in cases {
            #expect(FoodGroupResolver.resolve(source: "matvaretabellen", category: category) == group)
        }
        #expect(FoodGroupResolver.resolve(source: "user", category: "5.2") == .other)
        #expect(FoodGroupResolver.resolve(source: "matvaretabellen", category: nil) == .other)
        #expect(FoodGroupResolver.resolve(source: "matvaretabellen", category: "5.2", selected: "fish") == .fish)
        #expect(FoodGroupResolver.resolve(source: "user", category: nil, selected: "future_group") == .other)
    }

    @Test func offTagsHandleParentsDishesConflictsAndLocalizedText() {
        let cases: [([String], FoodGroup)] = [
            (["en:meats", "en:poultry"], .poultry), (["en:dairies", "en:cheeses"], .cheese),
            (["en:cereals", "en:rices"], .ricePasta), (["en:meats", "en:pizzas"], .other),
            (["en:fruits", "en:vegetables"], .other), (["en:plant-milks", "en:beverages"], .drinks),
            (["en:beverages", "en:dairies", "en:milks"], .dairy),
            (["en:fruits", "en:fruit-juices"], .drinks),
            (["en:unrecognized-category"], .other)
        ]
        for (tags, group) in cases {
            #expect(FoodGroupResolver.resolve(source: "openfoodfacts", category: nil, tags: tags) == group)
        }
        #expect(FoodGroupResolver.resolve(source: "openfoodfacts", category: "Brød, Korn") == .bread)
        #expect(FoodGroupResolver.resolve(source: "openfoodfacts", category: "Not a fish product") == .other)
    }

    @Test func legacyAndFutureProductsDecodeWithoutLosingRawMetadata() throws {
        let product = Product(name: "Synthetic", category: "en:rices", categoryTags: ["en:rices"],
            selectedFoodGroup: "future_group", source: "openfoodfacts",
            caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 20, fatGPer100g: 1)
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(product)) as? [String: Any])
        let future = try JSONDecoder().decode(Product.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(future.selectedFoodGroup == "future_group")
        #expect(future.foodGroup == .ricePasta)
        json.removeValue(forKey: "selectedFoodGroup")
        json.removeValue(forKey: "categoryTags")
        let legacy = try JSONDecoder().decode(Product.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(legacy.foodGroup == .ricePasta)
        let oldDraft = try JSONDecoder().decode(ManualProductInput.self,
            from: JSONEncoder().encode(ManualProductInput()))
        #expect(oldDraft.selectedFoodGroup == nil)
    }

    @Test func allVectorAssetsExistInBothAppearances() {
        for group in FoodGroup.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let image = UIImage(named: group.assetName, in: Bundle.main,
                                    compatibleWith: UITraitCollection(userInterfaceStyle: style))
                #expect(image != nil, "Missing asset: \(group.assetName)")
            }
        }
    }

    @Test func manualGroupSurvivesDraftReopeningAndExplicitClearing() async throws {
        try await withStore { store, url in
            let owner = UUID()
            let model = ManualProductViewModel(barcode: nil) { try store.saveProduct($0, ownerUserId: owner) }
            model.name = "Synthetic manual food"; model.calories = "100"
            model.protein = "2"; model.carbs = "20"; model.fat = "1"
            var didChange = false
            model.inputChanged = { didChange = true }
            model.selectedFoodGroup = .bread
            #expect(didChange)
            let draft = try JSONDecoder().decode(ManualProductInput.self, from: JSONEncoder().encode(model.input))
            let restored = ManualProductViewModel(barcode: nil) { try store.saveProduct($0, ownerUserId: owner) }
            restored.restoreInput(draft, productID: model.productID)
            #expect(restored.selectedFoodGroup == .bread)
            let product = try #require(await restored.save())
            let reopened = try LocalStore(databaseURL: url)
            #expect(reopened.getProduct(product.id)?.foodGroup == .bread)
            var event = try #require(reopened.fetchPendingEvents(limit: 20).last)
            var payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
            #expect(payload["selectedFoodGroup"] as? String == "bread")
            restored.selectedFoodGroup = nil
            _ = try #require(await restored.save())
            #expect(store.getProduct(product.id)?.selectedFoodGroup == nil)
            event = try #require(store.fetchPendingEvents(limit: 20).first(where: { $0.eventId != event.eventId }))
            payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
            #expect(payload["selectedFoodGroup"] is NSNull)
            #expect(payload["localImageData"] == nil)
            #expect(store.getProduct(product.id)?.caloriesPer100g == 100)
        }
    }

    @Test func existingProductEditorPreservesDataAndRejectsOtherOwners() async throws {
        try await withStore { store, _ in
            let owner = UUID()
            let original = Product(name: "Synthetic food", category: "raw category", source: "user",
                caloriesPer100g: 120, proteinGPer100g: 3, carbsGPer100g: 21, fatGPer100g: 2,
                localImageData: Data([1, 2]), nutritionSource: .user, imageSource: .user,
                nutritionBasis: .per100ml)
            try store.saveProduct(original, ownerUserId: owner)
            let model = ProductDetailViewModel(product: original, repository: NoFoodGroupCatalogIO(),
                                                metadataRepository: DatabaseService(store: store))
            await model.updateFoodGroup(.dairy, owner: UUID())
            #expect(model.foodGroupError != nil)
            #expect(store.getProduct(original.id)?.selectedFoodGroup == nil)
            #expect(store.fetchPendingEvents(limit: 20).count == 1)
            await model.updateFoodGroup(.dairy, owner: owner)
            #expect(model.foodGroupError == nil)
            let saved = try #require(store.getProduct(original.id))
            #expect(saved.foodGroup == .dairy)
            #expect(saved.caloriesPer100g == original.caloriesPer100g)
            #expect(saved.category == original.category)
            #expect(saved.localImageData == original.localImageData)
            #expect(saved.nutritionBasis == .per100ml)
            await model.updateFoodGroup(nil, owner: owner)
            #expect(model.product.foodGroup == .other)
            #expect(store.fetchPendingEvents(limit: 20).count == 3)
        }
    }

    private func withStore(_ operation: (LocalStore, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("food.sqlite")
        try await operation(LocalStore(databaseURL: url), url)
    }
}

@MainActor
private struct NoFoodGroupCatalogIO: BarcodeLookupRepository {
    func cached(barcode: String, owner: UUID?) async -> Product? { nil }
    func fetch(barcode: String) async throws -> Product { throw URLError(.notConnectedToInternet) }
    func refresh(_ product: Product, manually: Bool) async throws -> Product? { nil }
}
