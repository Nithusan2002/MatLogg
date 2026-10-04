import Foundation
import Combine

@MainActor
final class QuickLogViewModel: ObservableObject {
    @Published private(set) var recentFoods: [RecentFood] = []
    @Published private(set) var isRepeating = false {
        didSet {
            repeatFeedback.update(isActive: isRepeating) { [weak self] in self?.showsRepeatFeedback = $0 }
        }
    }
    @Published private(set) var repeatingProductID: UUID?
    @Published private(set) var showsRepeatFeedback = false
    private let repeatFeedback = DelayedActivity()
    @Published private(set) var logError: String?
    @Published private(set) var repeatReceipt: ReceiptPayload?
    @Published private(set) var confirmedProductID: UUID?
    @Published private(set) var isUndoingRepeat = false
    private var confirmationTask: Task<Void, Never>?
    @Published var selectedQuickProduct: Product?
    private var repeatID = UUID()
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false {
        didSet {
            loadingFeedback.update(isActive: isLoading) { [weak self] in self?.showsLoadingFeedback = $0 }
        }
    }
    @Published private(set) var showsLoadingFeedback = false
    private let loadingFeedback = DelayedActivity()
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?
    @Published var selectedManualProduct: Product?
    private var pendingManualProduct: Product?
    private var owner: UUID?
    private let repository: any FoodSearchRepository
    private var requestID = UUID()

    init(repository: any FoodSearchRepository) { self.repository = repository }

    func reset() {
        requestID = UUID()
        products = []
        recentFoods = []
        selectedQuickProduct = nil
        invalidateRepeatPresentation()
        owner = nil
        pendingManualProduct = nil
        selectedManualProduct = nil
        errorMessage = nil
        isLoading = false
        hasLoaded = false
    }

    func saveManual(_ product: Product) async throws {
        guard let owner else { throw DatabaseServiceError.unavailable }
        try await repository.saveManual(product, owner: owner)
        guard self.owner == owner, !Task.isCancelled else { throw CancellationError() }
    }

    func manualProductSaved(_ product: Product) { pendingManualProduct = product }

    func finishManualCreation() {
        selectedManualProduct = pendingManualProduct
        pendingManualProduct = nil
    }

    func invalidateRepeatPresentation() {
        repeatID = UUID()
        logError = nil
        dismissRepeatReceipt()
    }

    func dismissRepeatReceipt() {
        confirmationTask?.cancel()
        confirmationTask = nil
        repeatReceipt = nil
        confirmedProductID = nil
    }

    func showRepeatUndoError() {
        logError = "Kunne ikke angre loggingen. Prøv igjen."
    }

    func beginRepeatUndo() -> Bool {
        guard !isUndoingRepeat, !isRepeating else { return false }
        isUndoingRepeat = true
        logError = nil
        return true
    }

    func finishRepeatUndo() { isUndoingRepeat = false }

    func logAgain(_ food: RecentFood, mealType: String, date: Date) async -> (Product, FoodLog)? {
        guard !isRepeating, !isUndoingRepeat, let owner, food.log.userId == owner else { return nil }
        let request = UUID()
        repeatID = request
        repeatingProductID = food.id
        isRepeating = true
        logError = nil
        defer { isRepeating = false; repeatingProductID = nil }
        do {
            let outcome = try await repository.logAgain(food, owner: owner, mealType: mealType, date: date)
            guard repeatID == request, self.owner == owner, !Task.isCancelled else { return nil }
            switch outcome {
            case .logged(let product, let log):
                dismissRepeatReceipt()
                repeatReceipt = ReceiptPayload(product: product, amountG: Double(log.amountG),
                    amountUnit: log.resolvedAmountUnit, mealType: log.mealType,
                    loggedDate: log.loggedDate, portionSelection: log.portionSelection,
                    logID: log.id, ownerID: log.userId)
                confirmedProductID = food.id
                confirmationTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    self?.confirmedProductID = nil
                }
                return (product, log)
            case .review(let product):
                selectedQuickProduct = product
                return nil
            }
        } catch {
            guard repeatID == request, self.owner == owner, !Task.isCancelled else { return nil }
            logError = "Kunne ikke lagre på enheten. Prøv igjen."
            return nil
        }
    }

    func load(userId: UUID?) async {
        if owner != userId {
            hasLoaded = false
            products = []
            recentFoods = []
            invalidateRepeatPresentation()
            selectedQuickProduct = nil
            pendingManualProduct = nil
            selectedManualProduct = nil
        }
        owner = userId
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        do {
            let library = try await repository.loadQuickChoices(owner: userId)
            guard requestID == request, !Task.isCancelled else { return }
            recentFoods = library.recentFoods
            products = Array(FoodSearchMatcher.unique(library.favorites + library.recent).prefix(8))
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke hente hurtigvalg. Prøv igjen."
        }
        isLoading = false
        hasLoaded = true
    }
}
