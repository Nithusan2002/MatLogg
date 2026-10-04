import Foundation
import Testing
@testable import MatLogg

@MainActor
struct SavedMealNutritionPreviewTests {
    @Test func editsScaleSnapshotsAndSumUnroundedValuesWithMixedUnits() throws {
        let first = item(amount: 20, calories: 120, protein: 5, carbs: 2, fat: 10)
        let second = item(amount: 100, unit: .milliliters, calories: 50, protein: 3, carbs: 5, fat: 2)
        let meal = SavedMeal(userId: UUID(), name: "Testmåltid", items: [first, second])
        let model = SavedMealNutritionPreviewViewModel(meal: meal)
        #expect(model.preview.total?.calories == 170)
        model.setAmount(itemID: first.id, text: "40")
        model.setAmount(itemID: second.id, text: "12,5")
        let preview = model.preview
        #expect(preview.validAmounts?[first.id] == 40)
        #expect(preview.validAmounts?[second.id] == 12.5)
        #expect(preview.nutritionByItem[first.id]?.calories == 240)
        let total = try #require(preview.total)
        #expect(total.calories == 246.25)
        #expect(total.protein == 10.375)
        #expect(total.carbs == 4.625)
        #expect(total.fat == 20.25)
        #expect(meal.items == [first, second])
    }

    @Test func invalidInputHidesAffectedValuesAndTotalThenRecovers() {
        let first = item(), second = item()
        let model = SavedMealNutritionPreviewViewModel(
            meal: SavedMeal(userId: UUID(), name: "Testmåltid", items: [first, second]))
        for text in ["", "0", "-1", "10000.1", "nan", "inf", "abc"] {
            model.setAmount(itemID: first.id, text: text)
            #expect(model.preview.total == nil)
            #expect(model.preview.validAmounts == nil)
            #expect(model.preview.nutritionByItem[first.id] == nil)
            #expect(model.preview.nutritionByItem[second.id] != nil)
        }
        model.setAmount(itemID: first.id, text: "10000")
        #expect(model.preview.total != nil)
        #expect(model.preview.validAmounts?[first.id] == 10000)
    }

    @Test func missingOrInvalidSnapshotIsNotReplacedWithInventedValues() {
        let invalid = item(amount: 0), valid = item()
        let model = SavedMealNutritionPreviewViewModel(
            meal: SavedMeal(userId: UUID(), name: "Testmåltid", items: [invalid, valid]))
        model.setAmount(itemID: invalid.id, text: "20")
        #expect(model.preview.nutritionByItem[invalid.id] == nil)
        #expect(model.preview.nutritionByItem[valid.id] != nil)
        #expect(model.preview.total == nil)
        #expect(model.preview.validAmounts == nil)
    }

    @Test func initialAmountsKeepPrecisionAndDoNotUseGroupedInput() {
        let original = item(amount: 1234.5678)
        let meal = SavedMeal(userId: UUID(), name: "Testmåltid", items: [original])
        let model = SavedMealNutritionPreviewViewModel(meal: meal)
        #expect(model.preview.validAmounts?[original.id] == original.amountG)
        model.setAmount(itemID: original.id, text: "25")
        model.update(meal)
        #expect(model.preview.validAmounts?[original.id] == 25)
        var changed = meal
        changed.items[0].amountG = 50
        model.update(changed)
        #expect(model.preview.validAmounts?[original.id] == 50)
    }

    @Test func emptyMealHasNoTotalAndCannotBeLogged() {
        let model = SavedMealNutritionPreviewViewModel(
            meal: SavedMeal(userId: UUID(), name: "Tomt", items: []))
        #expect(model.preview.total == nil)
        #expect(model.preview.validAmounts == nil)
    }

    private func item(amount: Float = 100, unit: AmountUnit = .grams, calories: Float = 100,
                      protein: Float = 10, carbs: Float = 20, fat: Float = 5) -> SavedMealItem {
        SavedMealItem(productId: UUID(), productName: "Testvare", amountG: amount, amountUnit: unit,
                      calories: calories, proteinG: protein, carbsG: carbs, fatG: fat,
                      nutritionSource: .user, sortIndex: 0)
    }
}
