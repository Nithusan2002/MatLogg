import Foundation

/// Pure row copy, independent of SwiftUI, storage and nutrition calculations.
nonisolated struct FoodSearchRowPresentation {
    let identity: String?
    let brandText: String?
    let packageText: String?
    let kindTitle: String
    let sourceTitle: String
    let provenance: String
    let nutrition: String

    init(product: Product) {
        let kind: String
        if product.source == "user" { kind = "Egen matvare" }
        else { kind = product.kind == .genericFood ? "Generell matvare" : "Pakkevare" }
        let source = switch product.nutritionSource {
        case .matvaretabellen: "Matvaretabellen"
        case .openFoodFacts: "Open Food Facts"
        case .user: "Brukeroppgitt"
        }
        kindTitle = kind
        sourceTitle = source
        provenance = "\(kind) · \(source)"
        let prepared = product.nutritionPreparation == .prepared ? ", tilberedt" : ""
        nutrition = "\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal per 100 \(product.amountUnit.rawValue)\(prepared)"

        let brand = product.brand?.trimmingCharacters(in: .whitespacesAndNewlines)
        brandText = brand.flatMap { $0.isEmpty ? nil : $0 }
        packageText = Self.packageLabel(product).map { "Pakning: \($0)" }
        let parts = [brandText, packageText].compactMap { $0 }
        identity = parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func packageLabel(_ product: Product) -> String? {
        if let raw = ProductPackageLabel.validated(product.packageQuantityLabel) { return raw }
        // Older cached products can have explicit package metadata but no raw label.
        guard let package = product.servings?.first(where: {
            $0.kind == .package && $0.source != .heuristic && $0.unit != nil
                && $0.grams.isFinite && $0.grams > 0 && $0.grams <= 10_000
        }), let unit = package.unit else { return nil }
        return PortionDisplay.amount(package.grams, unit: unit, portion: nil)
    }
}
