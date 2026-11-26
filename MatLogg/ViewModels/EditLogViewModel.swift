import Foundation
import Combine

nonisolated struct LogEditRequest: Sendable {
    let amountG: Float
    let mealType: String
    let portionSelection: PortionSelection?
}

typealias LogEditOperation = @MainActor (LogEditRequest) async -> Bool

@MainActor
final class EditLogViewModel: ObservableObject {
    let amount: AmountSelectionViewModel
    @Published var mealType: String
    @Published private(set) var isSaving = false
    @Published private(set) var error: String?
    @Published private(set) var isFavorite: Bool?
    @Published private(set) var isChangingFavorite = false
    @Published private(set) var favoriteError: String?
    private let original: FoodLog
    private let favorites: (any ProductFavoriteRepository)?

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

    init(log: FoodLog, favorites: (any ProductFavoriteRepository)? = nil) {
        original = log
        self.favorites = favorites
        amount = AmountSelectionViewModel(unit: log.resolvedAmountUnit,
                                          servings: log.portionSelection.map { [$0.serving] } ?? [],
                                          amount: Double(log.amountG), portion: log.portionSelection,
                                          nutritionPreparation: log.nutritionPreparation)
        mealType = log.mealType
        amountChanges = amount.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private var favoriteReadRequest = UUID()

    func loadFavorite(owner: UUID?) async {
        let request = UUID()
        favoriteReadRequest = request
        guard owner == original.userId, let favorites else {
            isFavorite = nil
            favoriteError = nil
            return
        }
        guard !isChangingFavorite else { return }
        favoriteError = nil
        do {
            let saved = try await favorites.isFavorite(userId: original.userId, productId: original.productId)
            guard favoriteReadRequest == request, !Task.isCancelled else { return }
            isFavorite = saved
        } catch {
            guard favoriteReadRequest == request, !Task.isCancelled else { return }
            favoriteError = "Kunne ikke hente favorittstatus. Prøv igjen."
        }
    }

    func toggleFavorite(owner: UUID?) async -> Bool {
        guard owner == original.userId, let favorites, isFavorite != nil, favoriteError == nil,
              !isChangingFavorite, !isSaving else { return false }
        let request = UUID()
        favoriteReadRequest = request
        isChangingFavorite = true
        favoriteError = nil
        defer { isChangingFavorite = false }
        do {
            try await favorites.toggleFavorite(userId: original.userId, productId: original.productId)
            let saved = try await favorites.isFavorite(userId: original.userId, productId: original.productId)
            guard favoriteReadRequest == request, !Task.isCancelled else { return false }
            isFavorite = saved
            return true
        } catch {
            guard favoriteReadRequest == request, !Task.isCancelled else { return false }
            favoriteError = "Kunne ikke oppdatere favoritt. Prøv igjen."
            return false
        }
    }

    func save(_ operation: LogEditOperation) async -> Bool {
        guard canSave, let total = amount.amount else { return false }
        isSaving = true
        error = nil
        defer { isSaving = false }
        let request = LogEditRequest(amountG: Float(total), mealType: mealType, portionSelection: amount.portion)
        let success = await operation(request)
        if !success { error = "Kunne ikke lagre endringene. Prøv igjen." }
        return success
    }
}
