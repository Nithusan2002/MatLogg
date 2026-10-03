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
        nutritionSource: .openFoodFacts, imageSource: .none,
        nutriScoreInfo: ProductNutriScoreInfo(grade: "C", version: "2023", calculation:
            NutriScoreCalculation(positive: [], negative: [NutriScoreComponent(id: "energy", value: 398, unit: "kJ", points: 1, points_max: 10)],
                positivePoints: 0, positiveMaximum: 10, negativePoints: 1, negativeMaximum: 55,
                estimated: true, preparation: "as_sold", proteinExclusionReason: "negative_points_greater_than_or_equal_to_11")),
        processingInfo: ProductProcessingInfo(novaGroup: 4,
            markers: ["4": [["ingredients", "en:salt"], ["ingredients", "en:unknown"]]],
            ingredients: "Syntetisk ingrediensliste for UI-test."))
}
#endif
