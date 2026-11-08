import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published private(set) var period: ProgressPeriod = .week
    @Published private(set) var dateRange: ProgressDateRange
    @Published private(set) var overview = ProgressNutritionOverview(summaries: [], periodDays: 7)
    @Published private(set) var weightOverview: ProgressWeightOverview
    @Published private(set) var summaries: [DailySummary] = []
    @Published private(set) var metrics = ProgressMetrics(summaries: [])
    @Published private(set) var isLoading = true {
        didSet {
            loadingFeedback.update(isActive: isLoading) { [weak self] in self?.showsLoadingFeedback = $0 }
        }
    }
    @Published private(set) var showsLoadingFeedback = false
    private let loadingFeedback = DelayedActivity()
    @Published private(set) var errorMessage: String?
    private let repository: any FoodLogRepository
    private var requestID = UUID()
    private var owner: UUID?
    private let calendar: Calendar
    private let now: () -> Date
    private var anchorDate: Date
    private var preferredMonthDay: Int?
    private var weightEntries: [WeightEntry] = []

    init(repository: any FoodLogRepository, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
        anchorDate = calendar.startOfDay(for: now())
        let range = ProgressDateRange(period: .week, anchor: anchorDate, calendar: calendar)
        dateRange = range
        weightOverview = ProgressWeightOverview(entries: [], range: range.interval, owner: nil)
    }

    var isCurrentPeriod: Bool {
        let today = now()
        return today >= dateRange.interval.start && today < dateRange.interval.end
    }

    func selectPeriod(_ period: ProgressPeriod) {
        guard self.period != period else { return }
        self.period = period
        preferredMonthDay = nil
        selectRange(anchor: anchorDate)
    }

    func movePeriod(by offset: Int) {
        if period == .month {
            guard let start = calendar.date(byAdding: .month, value: offset, to: dateRange.interval.start),
                  let days = calendar.range(of: .day, in: .month, for: start) else { return }
            let preferredDay = preferredMonthDay ?? calendar.component(.day, from: anchorDate)
            let day = min(preferredDay, days.upperBound - 1)
            guard let anchor = calendar.date(byAdding: .day, value: day - days.lowerBound, to: start) else { return }
            preferredMonthDay = preferredDay
            selectRange(anchor: anchor)
        } else if let anchor = calendar.date(byAdding: period.component, value: offset, to: anchorDate) {
            selectRange(anchor: anchor)
        }
    }

    func goToCurrentPeriod() {
        guard !isCurrentPeriod else { return }
        preferredMonthDay = nil
        selectRange(anchor: calendar.startOfDay(for: now()))
    }

    private func selectRange(anchor: Date) {
        requestID = UUID()
        anchorDate = anchor
        dateRange = ProgressDateRange(period: period, anchor: anchor, calendar: calendar)
        summaries = []
        metrics = ProgressMetrics(summaries: [])
        overview = ProgressNutritionOverview(summaries: [], periodDays: dateRange.dates.count)
        weightOverview = ProgressWeightOverview(entries: weightEntries, range: dateRange.interval, owner: owner)
        isLoading = true
        errorMessage = nil
    }

    func updateWeights(_ entries: [WeightEntry], owner: UUID?) {
        guard self.owner == owner else { return }
        weightEntries = entries.filter { $0.userId == owner }
        weightOverview = ProgressWeightOverview(entries: weightEntries, range: dateRange.interval, owner: owner)
    }

    func reset() {
        requestID = UUID()
        owner = nil
        period = .week
        preferredMonthDay = nil
        anchorDate = calendar.startOfDay(for: now())
        dateRange = ProgressDateRange(period: .week, anchor: anchorDate, calendar: calendar)
        weightEntries = []
        weightOverview = ProgressWeightOverview(entries: [], range: dateRange.interval, owner: nil)
        overview = ProgressNutritionOverview(summaries: [], periodDays: dateRange.dates.count)
        summaries = []
        metrics = ProgressMetrics(summaries: [])
        isLoading = true
        errorMessage = nil
    }

    func load(userId: UUID?) async {
        if owner != userId {
            summaries = []
            metrics = ProgressMetrics(summaries: [])
            weightEntries = []
            weightOverview = ProgressWeightOverview(entries: [], range: dateRange.interval, owner: userId)
            overview = ProgressNutritionOverview(summaries: [], periodDays: dateRange.dates.count)
        }
        owner = userId
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        defer { if requestID == request { isLoading = false } }
        guard let userId else { return }
        let dates = dateRange.dates
        do {
            let loaded = try await repository.loadSummaries(userId: userId, dates: dates)
            guard requestID == request, !Task.isCancelled else { return }
            summaries = loaded
            metrics = ProgressMetrics(summaries: loaded)
            overview = ProgressNutritionOverview(summaries: loaded, periodDays: dates.count)
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke hente oversikten. Prøv igjen."
        }
    }
}
