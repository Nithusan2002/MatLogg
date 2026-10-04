import Combine
import Foundation

@MainActor
final class SavedMealDetailViewModel: ObservableObject {
    @Published private(set) var meal: SavedMeal
    @Published private(set) var isEditing = false
    @Published var name = ""
    @Published private(set) var removedIDs: Set<UUID> = []
    @Published private(set) var addedItems: [SavedMealItem] = []
    let nutrition: SavedMealNutritionPreviewViewModel
    private var observation: AnyCancellable?

    init(meal: SavedMeal) {
        self.meal = meal
        nutrition = SavedMealNutritionPreviewViewModel(meal: meal)
        observation = nutrition.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
    }

    var visibleItems: [SavedMealItem] {
        (meal.items + addedItems).filter { !removedIDs.contains($0.id) }.sorted { $0.sortIndex < $1.sortIndex }
    }

    var canSave: Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanName.isEmpty && cleanName.count <= 80 && !visibleItems.isEmpty
            && nutrition.preview.validAmounts != nil
    }

    func hasChanges(photoData: Data?) -> Bool {
        name != meal.name || !addedItems.isEmpty || !removedIDs.isEmpty || photoData != meal.localImageData
            || visibleItems.contains { nutrition.preview.validAmounts?[$0.id] != $0.amountG }
    }

    func beginEditing() {
        name = meal.name
        removedIDs = []
        addedItems = []
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

    func existingItem(for product: Product) -> SavedMealItem? {
        visibleItems.first { $0.productId == product.id }
    }

    @discardableResult
    func add(_ product: Product, amount: Float) -> Bool {
        guard isEditing, amount.isFinite, amount > 0, amount <= 10_000 else { return false }
        if let existing = existingItem(for: product) {
            nutrition.setAmount(itemID: existing.id, text: String(amount))
            return true
        }
        guard [product.caloriesPer100g, product.proteinGPer100g,
               product.carbsGPer100g, product.fatGPer100g]
            .allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        let values = product.calculateNutrition(forAmount: amount)
        guard [values.calories, values.protein, values.carbs, values.fat].allSatisfy({ $0.isFinite && $0 >= 0 }),
              values.calories <= Float(Int32.max) else { return false }
        addedItems.append(SavedMealItem(productId: product.id, productName: product.name,
            amountG: amount, amountUnit: product.amountUnit,
            calories: values.calories, proteinG: values.protein, carbsG: values.carbs,
            fatG: values.fat, nutritionSource: product.nutritionSource,
            sortIndex: (visibleItems.map(\.sortIndex).max() ?? -1) + 1))
        var draft = meal
        draft.items = visibleItems
        let texts = nutrition.preview.amountTexts
        nutrition.update(draft)
        for (id, text) in texts { nutrition.setAmount(itemID: id, text: text) }
        return true
    }

    func cancelEditing() { isEditing = false }

    func save(using repositoryModel: SavedMealsViewModel) async -> Bool {
        guard canSave, let amounts = nutrition.preview.validAmounts else { return false }
        guard await repositoryModel.update(meal, name: name, amounts: amounts, removedItemIDs: removedIDs, addedItems: addedItems),
              let saved = repositoryModel.meals.first(where: { $0.id == meal.id }) else { return false }
        meal = saved
        isEditing = false
        return true
    }
}
