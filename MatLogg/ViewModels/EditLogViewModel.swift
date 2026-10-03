import Foundation
import Combine

@MainActor
final class EditLogViewModel: ObservableObject {
    let amount: AmountSelectionViewModel
    @Published var mealType: String
    @Published private(set) var isSaving = false
    @Published private(set) var error: String?
    private var amountChanges: AnyCancellable?

    init(log: FoodLog) {
        amount = AmountSelectionViewModel(unit: log.resolvedAmountUnit,
                                          servings: log.portionSelection.map { [$0.serving] } ?? [],
                                          amount: Double(log.amountG), portion: log.portionSelection)
        mealType = log.mealType
        amountChanges = amount.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func save(_ operation: (Float, String, PortionSelection?) async -> Bool) async -> Bool {
        guard !isSaving, amount.isValid, let total = amount.amount else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        let success = await operation(Float(total), mealType, amount.portion)
        if !success { error = "Kunne ikke lagre endringene. Prøv igjen." }
        return success
    }
}
