import Combine
import Foundation

struct LogListPresentation {
    let groups: [(mealType: String, logs: [FoodLog])]
    let mealLogs: [FoodLog]
    let totals: NutritionBreakdown
}

/// Search results and meal totals have different invalidation inputs.
@MainActor
final class LogScreenViewModel: ObservableObject {
    @Published var searchText = "" { didSet { if oldValue != searchText { updatePresentation(recomputeMeal: false) } } }
    @Published var mealFilter: String? {
        didSet { if oldValue != mealFilter { updatePresentation(recomputeMeal: true) } }
    }
    @Published private(set) var summary: DailySummary?
    @Published private(set) var names: [UUID: String] = [:]
    @Published private(set) var brands: [UUID: String] = [:]
    @Published private(set) var imageURLs: [UUID: URL] = [:]
    @Published private(set) var imageData: [UUID: Data] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var presentation = LogListPresentation(groups: [], mealLogs: [],
        totals: NutritionCalculator.totals(for: []))
    private var subscriptions = Set<AnyCancellable>()

    init(logs: LogViewModel, appState: AppState? = nil, auth: AuthViewModel? = nil,
         savedMeals: SavedMealsViewModel? = nil, mealFilter: String? = nil) {
        self.mealFilter = mealFilter
        logs.$selectedDay.sink { [weak self] day in
            guard let self else { return }
            self.summary = day.summary
            self.names = day.productNames
            self.updatePresentation(recomputeMeal: true)
        }.store(in: &subscriptions)
        logs.$mealProductBrands.removeDuplicates().assign(to: &$brands)
        logs.$mealProductImageURLs.removeDuplicates().assign(to: &$imageURLs)
        logs.$mealProductImageData.removeDuplicates().assign(to: &$imageData)
        logs.$isSummaryLoading.removeDuplicates().assign(to: &$isLoading)
        if let appState { observe(appState.$logSelectedDate.removeDuplicates()) }
        if let auth { observe(auth.$currentUser.map { $0?.id }.removeDuplicates()) }
        observe(logs.$mutationRevision.removeDuplicates())
        observe(logs.$yesterdaySummary)
        if let savedMeals { observe(savedMeals.$mutationRevision.removeDuplicates()) }
    }

    private func observe<P: Publisher>(_ publisher: P) where P.Failure == Never {
        publisher.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
    }

    private func updatePresentation(recomputeMeal: Bool) {
        let logs = recomputeMeal
            ? (summary?.logs ?? []).filter { mealFilter == nil || $0.mealType == mealFilter }
            : presentation.mealLogs
        let totals = recomputeMeal ? NutritionCalculator.totals(for: logs) : presentation.totals
        let groups = LogSummaryService.groupedLogs(logs: logs, searchText: searchText,
                                                  productNameLookup: { names[$0] ?? "" })
        presentation = LogListPresentation(groups: groups, mealLogs: logs, totals: totals)
    }

}

struct LogDeletionReceipt: Equatable {
    let id: UUID?
    let count: Int
    let isBusy: Bool
}

@MainActor
final class LogDeletionReceiptViewModel: ObservableObject {
    @Published private(set) var receipt = LogDeletionReceipt(id: nil, count: 0, isBusy: false)
    init(logs: LogViewModel) {
        logs.$deletionReceiptID.combineLatest(logs.$deletedLogCount, logs.$isDeletingOrRestoring)
            .map { LogDeletionReceipt(id: $0, count: $1, isBusy: $2) }
            .removeDuplicates().assign(to: &$receipt)
    }
}
