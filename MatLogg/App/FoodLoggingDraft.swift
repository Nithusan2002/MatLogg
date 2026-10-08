import Foundation

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
    var amountText = "100"
    var selectedServing: ServingOption?
    var mealType: String
    var date: Date
}
