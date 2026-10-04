import Combine
import Foundation

@MainActor
final class SavedMealDetailViewModel: ObservableObject {
    @Published private(set) var meal: SavedMeal
    @Published private(set) var isEditing = false
    @Published var name = ""
    @Published private(set) var removedIDs: Set<UUID> = []
    let nutrition: SavedMealNutritionPreviewViewModel
    private var observation: AnyCancellable?

    init(meal: SavedMeal) {
        self.meal = meal
        nutrition = SavedMealNutritionPreviewViewModel(meal: meal)
        observation = nutrition.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    var visibleItems: [SavedMealItem] {
        meal.items.filter { !removedIDs.contains($0.id) }.sorted { $0.sortIndex < $1.sortIndex }
    }

    var canSave: Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanName.isEmpty && cleanName.count <= 80 && !visibleItems.isEmpty
            && nutrition.preview.validAmounts != nil
    }

    func hasChanges(photoData: Data?) -> Bool {
        name != meal.name || !removedIDs.isEmpty || photoData != meal.localImageData
            || visibleItems.contains { nutrition.preview.validAmounts?[$0.id] != $0.amountG }
    }

    func beginEditing() {
        name = meal.name
        removedIDs = []
        nutrition.reset(meal)
        isEditing = true
    }

    func remove(_ item: SavedMealItem) {
        removedIDs.insert(item.id)
        var draft = meal
        draft.items = visibleItems
        let texts = nutrition.preview.amountTexts
        nutrition.update(draft)
        for (id, text) in texts { nutrition.setAmount(itemID: id, text: text) }
    }

    func cancelEditing() { isEditing = false }

    func save(using repositoryModel: SavedMealsViewModel) async -> Bool {
        guard canSave, let amounts = nutrition.preview.validAmounts else { return false }
        guard await repositoryModel.update(meal, name: name, amounts: amounts, removedItemIDs: removedIDs),
              let saved = repositoryModel.meals.first(where: { $0.id == meal.id }) else { return false }
        meal = saved
        isEditing = false
        return true
    }
}
