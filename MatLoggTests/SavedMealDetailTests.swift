import Foundation
import Testing
@testable import MatLogg

@MainActor
struct SavedMealDetailTests {
    private func meal() -> SavedMeal {
        SavedMeal(userId: UUID(), name: "Frokost", suggestedMealType: "frokost", items: [
            SavedMealItem(productId: UUID(), productName: "Havregryn", amountG: 50,
                          calories: 200, proteinG: 10, carbsG: 30, fatG: 4,
                          nutritionSource: .matvaretabellen, sortIndex: 0)
        ])
    }

    @Test func cancelAndReopenRestoresOriginalDraft() {
        let original = meal()
        let model = SavedMealDetailViewModel(meal: original)
        model.beginEditing()
        model.name = "Endret"
        model.nutrition.setAmount(itemID: original.items[0].id, text: "75")
        #expect(model.hasChanges(photoData: nil))
        model.remove(original.items[0])
        #expect(!model.canSave)
        model.cancelEditing()
        #expect(model.meal == original)
        model.beginEditing()
        #expect(model.canSave)
        #expect(!model.hasChanges(photoData: nil))
        #expect(model.nutrition.preview.validAmounts?[original.items[0].id] == 50)
    }

    @Test func invalidInputAndPhotoChangesAreDetected() {
        let original = meal()
        let model = SavedMealDetailViewModel(meal: original)
        model.beginEditing()
        #expect(model.hasChanges(photoData: Data([1])))
        model.name = " "
        #expect(!model.canSave)
        model.name = original.name
        model.nutrition.setAmount(itemID: original.items[0].id, text: "0")
        #expect(!model.canSave)
        #expect(model.hasChanges(photoData: nil))
    }
}
