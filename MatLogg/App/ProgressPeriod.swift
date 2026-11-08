import Foundation

nonisolated enum ProgressPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }
    var title: String {
        switch self { case .day: "Dag"; case .week: "Uke"; case .month: "Måned" }
    }
    var component: Calendar.Component {
        switch self { case .day: .day; case .week: .weekOfYear; case .month: .month }
    }
    var previousLabel: String {
        switch self { case .day: "Forrige dag"; case .week: "Forrige uke"; case .month: "Forrige måned" }
    }
    var nextLabel: String {
        switch self { case .day: "Neste dag"; case .week: "Neste uke"; case .month: "Neste måned" }
    }
}

nonisolated struct ProgressDateRange {
    let interval: DateInterval
    let dates: [Date]
    let label: String

    init(period: ProgressPeriod, anchor: Date, calendar: Calendar) {
        var calendar = calendar
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        interval = calendar.dateInterval(of: period.component, for: anchor)
            ?? DateInterval(start: calendar.startOfDay(for: anchor), duration: 0)
        var days: [Date] = []
        var cursor = interval.start
        while cursor < interval.end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        dates = days
        let locale = Locale(identifier: "nb_NO")
        switch period {
        case .day:
            label = anchor.formatted(.dateTime.day().month(.wide).year().locale(locale))
        case .month:
            label = anchor.formatted(.dateTime.month(.wide).year().locale(locale)).capitalized
        case .week:
            let last = days.last ?? interval.start
            if calendar.component(.month, from: interval.start) == calendar.component(.month, from: last) {
                label = "\(calendar.component(.day, from: interval.start))–\(last.formatted(.dateTime.day().month(.wide).year().locale(locale)))"
            } else {
                label = "\(interval.start.formatted(.dateTime.day().month(.abbreviated).locale(locale)))–\(last.formatted(.dateTime.day().month(.abbreviated).year().locale(locale)))"
            }
        }
    }
}

nonisolated struct ProgressNutritionOverview {
    let recordedDays: [DailySummary]
    let averageCalories: Int?
    let protein: Float?
    let carbs: Float?
    let fat: Float?
    let coverage: String
    let chartUpperBound: Double

    init(summaries: [DailySummary], periodDays: Int) {
        recordedDays = summaries.filter { !$0.logs.isEmpty }
        let maximum = Double(recordedDays.map(\.totalCalories).filter { $0.isFinite && $0 >= 0 }.max() ?? 0)
        chartUpperBound = max(500, (maximum / 500).rounded(.up) * 500)
        let count = Float(recordedDays.count)
        if count > 0 {
            averageCalories = NutritionDisplay.wholeCalories(recordedDays.reduce(0) { $0 + $1.totalCalories } / count)
            protein = recordedDays.reduce(0) { $0 + $1.totalProtein } / count
            carbs = recordedDays.reduce(0) { $0 + $1.totalCarbs } / count
            fat = recordedDays.reduce(0) { $0 + $1.totalFat } / count
        } else {
            averageCalories = nil; protein = nil; carbs = nil; fat = nil
        }
        coverage = "\(recordedDays.count) av \(periodDays) dager logget"
    }
}

nonisolated struct ProgressWeightMeasurement: Equatable, Identifiable, Sendable {
    let id: UUID
    let date: Date
    let weightKg: Double
}

nonisolated struct ProgressWeightOverview: Equatable, Sendable {
    enum Source: String, Sendable {
        case matLogg = "MatLogg"
        case appleHealth = "Apple Helse"
    }

    let latest: ProgressWeightMeasurement?
    let points: [ProgressWeightMeasurement]
    let source: Source
    let chartLowerBound: Double
    let chartUpperBound: Double

    init(entries: [WeightEntry], range: DateInterval, owner: UUID?) {
        let valid = entries.filter { $0.userId == owner && $0.weightKg.isFinite && $0.weightKg > 0 && $0.date < range.end }
            .sorted { $0.date == $1.date ? $0.createdAt < $1.createdAt : $0.date < $1.date }
            .map { ProgressWeightMeasurement(id: $0.id, date: $0.date, weightKg: $0.weightKg) }
        self.init(latest: valid.last, points: valid.filter { $0.date >= range.start })
    }

    init(latest: ProgressWeightMeasurement?, points: [ProgressWeightMeasurement], source: Source = .matLogg) {
        self.latest = latest
        self.points = points
        self.source = source
        let lower = points.map(\.weightKg).min() ?? 0
        let upper = points.map(\.weightKg).max() ?? 0
        let padding = max((upper - lower) * 0.2, 1)
        chartLowerBound = max(0, lower - padding)
        chartUpperBound = upper + padding
    }

    func showingLatest(with health: ProgressWeightOverview?) -> ProgressWeightOverview {
        guard let health, let healthDate = health.latest?.date else { return self }
        if let localDate = latest?.date, localDate >= healthDate { return self }
        return health
    }
}

nonisolated struct HealthWeightSnapshot: HealthReadSnapshot {
    let range: DateInterval
    let overview: ProgressWeightOverview
    var isExampleData = false

    var hasData: Bool { overview.latest != nil }
}
