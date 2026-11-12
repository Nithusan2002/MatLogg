import Foundation

nonisolated enum ManualProductStep: String, Codable, Sendable, CaseIterable {
    case identity, basis, nutrition

    var title: String {
        switch self {
        case .identity: return "Om matvaren"
        case .basis: return "Næringsgrunnlag"
        case .nutrition: return "Næringsverdier"
        }
    }
}

nonisolated struct ManualProductInput: Codable, Sendable {
    var name = ""
    var calories = ""
    var protein = ""
    var carbs = ""
    var fat = ""
    var basis: ManualNutritionBasis = .per100g
    var servingName = ""
    var servingAmount = ""
    var servingUnit: AmountUnit = .grams
    var imageData: Data?
    var selectedFoodGroup: String?
    // Optional additions preserve decoding of drafts written before the wizard.
    var brand: String?
    var hasCustomServing: Bool?
    var wizardStep: ManualProductStep?
    var barcode: String?
}

nonisolated struct FoodLoggingDraft: Codable, Identifiable, Sendable {
    enum Step: String, Codable, Sendable { case product, amount }
    var id = UUID()
    var userId: UUID
    var productId = UUID()
    var logId = UUID()
    var schemaVersion = 1
    var revision = 0
    var updatedAt = Date()
    var step: Step = .product
    var barcode: String?
    var input = ManualProductInput()
    var product: Product?
    var manualProductId: UUID?
    var amountText = "100"
    var selectedServing: ServingOption?
    var mealType: String
    var date: Date
}
