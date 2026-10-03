#if DEBUG
import Foundation

/// Synthetic catalog record available only under the explicit UI-test launch argument.
enum PortionQAFixture {
    static let product = Product(
        id: Product.catalogID(source: "qa", externalID: "portion-bread"),
        name: "Porsjonstestbrød", source: "openfoodfacts", kind: .packaged,
        caloriesPer100g: 260, proteinGPer100g: 10, carbsGPer100g: 40, fatGPer100g: 4,
        servings: [ServingOption(id: Product.catalogID(source: "qa", externalID: "bread-piece"),
            label: "1 Polarbrød (37,5 g)", grams: 37.5, source: .openFoodFacts,
            isDefaultSuggestion: true, kind: .piece, shortLabel: "Polarbrød")],
        nutritionSource: .openFoodFacts, imageSource: .none)
}
#endif
