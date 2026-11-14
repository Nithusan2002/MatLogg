import Combine
import Foundation

struct SavedMealNutritionPreview {
    let amountTexts: [UUID: String]
    let validAmounts: [UUID: Float]?
    let nutritionByItem: [UUID: NutritionBreakdown]
    let total: NutritionBreakdown?
    let errorsByItem: [UUID: String]
}

/// Uses the saved snapshot, just like logging, without refreshing product nutrition.
@MainActor
final class SavedMealNutritionPreviewViewModel: ObservableObject {
    @Published private(set) var preview: SavedMealNutritionPreview
    private var items: [SavedMealItem]

    init(meal: SavedMeal) {
        items = meal.items
        preview = Self.makePreview(items: meal.items, texts: Self.initialTexts(meal.items))
    }

    func update(_ meal: SavedMeal) {
        guard items != meal.items else { return }
        items = meal.items
        preview = Self.makePreview(items: items, texts: Self.initialTexts(items))
    }

    func reset(_ meal: SavedMeal) {
        items = meal.items
        preview = Self.makePreview(items: items, texts: Self.initialTexts(items))
    }

    func setAmount(itemID: UUID, text: String) {
        guard items.contains(where: { $0.id == itemID }) else { return }
        var texts = preview.amountTexts
        texts[itemID] = text
        preview = Self.makePreview(items: items, texts: texts)
    }

    private static func initialTexts(_ items: [SavedMealItem]) -> [UUID: String] {
        Dictionary(uniqueKeysWithValues: items.map {
            ($0.id, $0.amountG.formatted(.number.locale(Locale(identifier: "nb_NO"))
                .grouping(.never).precision(.fractionLength(0...9))))
        })
    }

    private static func makePreview(items: [SavedMealItem], texts: [UUID: String]) -> SavedMealNutritionPreview {
        var amounts: [UUID: Float] = [:]
        var nutrition: [UUID: NutritionBreakdown] = [:]
        var errors: [UUID: String] = [:]
        var total = NutritionBreakdown(calories: 0, protein: 0, carbs: 0, fat: 0)
        for item in items {
            let text = texts[item.id, default: ""].replacingOccurrences(of: ",", with: ".")
            guard let amount = Float(text), amount.isFinite, amount > 0,
                  amount <= NutritionCalculator.maximumAmount else {
                errors[item.id] = "Skriv en mengde over 0 og høyst 10 000 \(item.resolvedAmountUnit.rawValue) for å vise næringsinnholdet."
                continue
            }
            guard let value = NutritionCalculator.scaledSnapshot(
                calories: item.calories, protein: item.proteinG, carbs: item.carbsG, fat: item.fatG,
                from: item.amountG, to: amount
            ), value.calories <= Float(Int32.max) else {
                errors[item.id] = "Næringsinnholdet kan ikke beregnes fra måltidets lagrede grunnlag."
                continue
            }
            amounts[item.id] = amount
            nutrition[item.id] = value
            total = NutritionBreakdown(
                calories: total.calories + value.calories, protein: total.protein + value.protein,
                carbs: total.carbs + value.carbs, fat: total.fat + value.fat
            )
        }
        let complete = !items.isEmpty && amounts.count == items.count
        return SavedMealNutritionPreview(amountTexts: texts, validAmounts: complete ? amounts : nil,
                                         nutritionByItem: nutrition, total: complete ? total : nil, errorsByItem: errors)
    }
}
