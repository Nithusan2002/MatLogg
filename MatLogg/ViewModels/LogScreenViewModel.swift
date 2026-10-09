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
    @Published private(set) var isDeletingOrRestoring = false
    @Published private(set) var isSelecting = false
    @Published private(set) var selectedLogIDs: Set<UUID> = []

    var selectedLogs: [FoodLog] { presentation.mealLogs.filter { selectedLogIDs.contains($0.id) } }
    var canSaveSelection: Bool { (1...50).contains(selectedLogs.count) }
    var selectionMealType: String { selectedLogs.first?.mealType ?? "frokost" }
    var selectionSpansMeals: Bool { Set(selectedLogs.map(\.mealType)).count > 1 }

    func isGroupSelected(_ mealType: String? = nil) -> Bool {
        let ids = Set(presentation.mealLogs.filter { mealType == nil || $0.mealType == mealType }.map(\.id))
        return !ids.isEmpty && ids.isSubset(of: selectedLogIDs)
    }

    func beginSelection() {
        guard !isLoading, !isDeletingOrRestoring, !presentation.mealLogs.isEmpty else { return }
        selectedLogIDs = []
        isSelecting = true
    }

    func endSelection() {
        if isSelecting { isSelecting = false }
        if !selectedLogIDs.isEmpty { selectedLogIDs = [] }
    }

    func toggleSelection(_ id: UUID) {
        guard isSelecting, !isDeletingOrRestoring, presentation.mealLogs.contains(where: { $0.id == id }) else { return }
        if selectedLogIDs.contains(id) { selectedLogIDs.remove(id) }
        else { selectedLogIDs.insert(id) }
    }

    func toggleGroup(_ mealType: String? = nil) {
        guard isSelecting, !isDeletingOrRestoring else { return }
        let ids = Set(presentation.mealLogs.filter { mealType == nil || $0.mealType == mealType }.map(\.id))
        if ids.isSubset(of: selectedLogIDs) { selectedLogIDs.subtract(ids) }
        else { selectedLogIDs.formUnion(ids) }
    }

    private let includesEmptyMeals: Bool
    private var subscriptions = Set<AnyCancellable>()

    init(logs: LogViewModel, appState: AppState? = nil, auth: AuthViewModel? = nil,
         savedMeals: SavedMealsViewModel? = nil, mealFilter: String? = nil, includesEmptyMeals: Bool = false) {
        self.includesEmptyMeals = includesEmptyMeals
        self.mealFilter = mealFilter
        logs.$selectedDay.sink { [weak self] day in
            guard let self else { return }
            if day.summary == nil { self.endSelection() }
            if let previous = self.summary, let next = day.summary,
               !Calendar.current.isDate(previous.date, inSameDayAs: next.date) {
                self.endSelection()
            }
            self.summary = day.summary
            self.names = day.productNames
            self.updatePresentation(recomputeMeal: true)
        }.store(in: &subscriptions)
        logs.$mealProductBrands.removeDuplicates().assign(to: &$brands)
        logs.$mealProductImageURLs.removeDuplicates().assign(to: &$imageURLs)
        logs.$mealProductImageData.removeDuplicates().assign(to: &$imageData)
        logs.$isSummaryLoading.removeDuplicates().assign(to: &$isLoading)
        logs.$isDeletingOrRestoring.removeDuplicates().assign(to: &$isDeletingOrRestoring)
        if let appState { observe(appState.$logSelectedDate.removeDuplicates()) }
        if let auth {
            auth.$currentUser.map { $0?.id }.removeDuplicates().dropFirst()
                .sink { [weak self] _ in self?.endSelection() }.store(in: &subscriptions)
        }
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
        var groups = LogSummaryService.groupedLogs(logs: logs, searchText: searchText,
                                                  productNameLookup: { names[$0] ?? "" })
        if includesEmptyMeals, mealFilter == nil, searchText.isEmpty {
            groups = LogSummaryService.mealOrder.map { meal in
                (meal, groups.first(where: { $0.mealType == meal })?.logs ?? [])
            }
        }
        let retained = selectedLogIDs.intersection(Set(logs.map(\.id)))
        if retained != selectedLogIDs { selectedLogIDs = retained }
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
