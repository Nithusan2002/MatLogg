#if DEBUG
import Foundation

/// Synthetic products, seeded only with the explicit --search-metadata-qa argument.
enum SearchMetadataQAFixture {
    static let products = [
        Product(id: Product.catalogID(source: "qa", externalID: "package-500"),
            name: "Pakningstest drikk", brand: "Eksempelmerke", source: "openfoodfacts",
            caloriesPer100g: 42, proteinGPer100g: 0, carbsGPer100g: 10, fatGPer100g: 0,
            nutritionSource: .openFoodFacts, imageSource: .none, nutritionBasis: .per100ml,
            packageQuantityLabel: "500 ml"),
        Product(id: Product.catalogID(source: "qa", externalID: "package-1000"),
            name: "Pakningstest drikk", brand: "Eksempelmerke", source: "openfoodfacts",
            caloriesPer100g: 42, proteinGPer100g: 0, carbsGPer100g: 10, fatGPer100g: 0,
            nutritionSource: .openFoodFacts, imageSource: .none, nutritionBasis: .per100ml,
            packageQuantityLabel: "1 l"),
        Product(id: Product.catalogID(source: "qa", externalID: "generic-oats"),
            name: "Pakningstest havregryn", source: "matvaretabellen", kind: .genericFood,
            caloriesPer100g: 370, proteinGPer100g: 13, carbsGPer100g: 60, fatGPer100g: 7,
            nutritionSource: .matvaretabellen, imageSource: .none)
    ]
}
#endif
