import Foundation
import Combine

@MainActor
final class EditLogViewModel: ObservableObject {
    let amount: AmountSelectionViewModel
    @Published var mealType: String
    @Published private(set) var isSaving = false
    @Published private(set) var error: String?
    private let original: FoodLog

    var hasChanges: Bool {
        guard let total = amount.amount else { return false }
        return Float(total) != original.amountG || mealType != original.mealType
            || amount.portion != original.portionSelection
    }

    var nutrition: NutritionBreakdown? {
        guard amount.isValid, let total = amount.amount else { return nil }
        return NutritionCalculator.scaledSnapshot(
            calories: original.calories, protein: original.proteinG,
            carbs: original.carbsG, fat: original.fatG,
            from: original.amountG, to: Float(total))
    }

    var canSave: Bool { hasChanges && amount.isValid && nutrition != nil && !isSaving }

    private var amountChanges: AnyCancellable?

    init(log: FoodLog) {
        original = log
        amount = AmountSelectionViewModel(unit: log.resolvedAmountUnit,
                                          servings: log.portionSelection.map { [$0.serving] } ?? [],
                                          amount: Double(log.amountG), portion: log.portionSelection)
        mealType = log.mealType
        amountChanges = amount.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func save(_ operation: (Float, String, PortionSelection?) async -> Bool) async -> Bool {
        guard canSave, let total = amount.amount else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        let success = await operation(Float(total), mealType, amount.portion)
        if !success { error = "Kunne ikke lagre endringene. Prøv igjen." }
        return success
    }
}
