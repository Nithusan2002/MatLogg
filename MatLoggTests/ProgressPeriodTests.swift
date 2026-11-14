import Foundation
import Testing
@testable import MatLogg

@MainActor
struct ProgressPeriodTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar? = nil) -> Date {
        (calendar ?? self.calendar).date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func calendarPeriodsUseMondayAndFullMonthIncludingLeapYear() {
        let anchor = date(2026, 11, 6)
        let week = ProgressDateRange(period: .week, anchor: anchor, calendar: calendar)
        #expect(week.dates.count == 7)
        #expect(calendar.component(.day, from: week.dates[0]) == 2)
        #expect(calendar.component(.day, from: week.dates[6]) == 8)
        #expect(ProgressDateRange(period: .day, anchor: anchor, calendar: calendar).dates.count == 1)
        #expect(ProgressDateRange(period: .month, anchor: anchor, calendar: calendar).dates.count == 30)
        #expect(ProgressDateRange(period: .month, anchor: date(2028, 2, 15), calendar: calendar).dates.count == 29)
    }

    @Test func localCalendarHandlesDaylightSavingWithoutDuplicatingDays() {
        var oslo = calendar
        oslo.timeZone = TimeZone(identifier: "Europe/Oslo")!
        let range = ProgressDateRange(period: .week, anchor: date(2026, 10, 25, calendar: oslo), calendar: oslo)
        #expect(range.dates.count == 7)
        #expect(Set(range.dates).count == 7)
        #expect(range.interval.duration == 7 * 86400 + 3600)
        #expect(range.dates.allSatisfy { oslo.component(.hour, from: $0) == 0 })
    }

    @Test func averagesUseOnlyLoggedDaysAndDoNotTurnMissingDaysIntoZero() {
        let owner = UUID(), first = date(2026, 11, 2), second = date(2026, 11, 3)
        let missing = DailySummary(date: date(2026, 11, 4), totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
        let overview = ProgressNutritionOverview(summaries: [summary(owner, first, calories: 100), summary(owner, second, calories: 300), missing], periodDays: 7)
        #expect(overview.averageCalories == 200)
        #expect(overview.protein == 20)
        #expect(overview.chartUpperBound == 500)
        #expect(overview.recordedDays.count == 2)
        #expect(overview.coverage == "2 av 7 dager logget")
        let zero = ProgressNutritionOverview(summaries: [summary(owner, first, calories: 100), summary(owner, second, calories: 0)], periodDays: 7)
        #expect(zero.averageCalories == 50)
        #expect(ProgressNutritionOverview(summaries: [missing], periodDays: 7).averageCalories == nil)
    }

    @Test func dayMacroDistributionUsesEnergyAndFallsBackWhenEnergyHasNoMacros() throws {
        let owner = UUID()
        let day = date(2026, 11, 2)
        let food = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                           loggedDate: day, calories: 100, proteinG: 10, carbsG: 0, fatG: 5)
        let water = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                            loggedDate: day, calories: 0, proteinG: 0, carbsG: 0, fatG: 0)
        let energyOnly = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                                 loggedDate: day, calories: 20, proteinG: 0, carbsG: 0, fatG: 0)
        let summaries = DailySummary.summaries(userId: owner, dates: [day], logs: [food, water], calendar: calendar)
        let overview = ProgressNutritionOverview(summaries: summaries, periodDays: 1)
        let distribution = try #require(overview.dayMacroDistribution)
        #expect(abs(distribution.protein - 40.0 / 85.0) < 0.000001)
        #expect(distribution.carbs == 0)
        #expect(abs(distribution.fat - 45.0 / 85.0) < 0.000001)
        #expect(overview.averageCalories == 100)
        #expect(ProgressNutritionOverview(summaries: summaries, periodDays: 7).dayMacroDistribution == nil)

        let incomplete = DailySummary.summaries(userId: owner, dates: [day], logs: [food, energyOnly], calendar: calendar)
        let fallback = ProgressNutritionOverview(summaries: incomplete, periodDays: 1)
        #expect(fallback.dayMacroDistribution == nil)
        #expect(fallback.averageCalories == 120)
        let zero = DailySummary.summaries(userId: owner, dates: [day], logs: [water], calendar: calendar)
        #expect(ProgressNutritionOverview(summaries: zero, periodDays: 1).dayMacroDistribution == nil)
    }

    @Test func periodChangesLoadRealDateRangesAndNavigationCrossesYearBoundary() async {
        let repository = PeriodRepository(calendar: calendar)
        let model = ProgressViewModel(repository: repository, calendar: calendar, now: { self.date(2026, 11, 6) })
        let owner = UUID()
        await model.load(userId: owner)
        #expect(repository.dates.last?.count == 7)
        model.selectPeriod(.day)
        await model.load(userId: owner)
        #expect(repository.dates.last?.count == 1)
        #expect(calendar.component(.day, from: model.dateRange.interval.start) == 6)
        model.selectPeriod(.month)
        await model.load(userId: owner)
        #expect(repository.dates.last?.count == 30)
        model.movePeriod(by: 1)
        model.movePeriod(by: 1)
        await model.load(userId: owner)
        #expect(calendar.component(.year, from: model.dateRange.interval.start) == 2027)
        #expect(calendar.component(.month, from: model.dateRange.interval.start) == 1)
        #expect(repository.dates.last?.count == 31)
    }

    @Test func weekOverviewAlignsSourcesAndPreservesZeroAcrossMonthBoundary() {
        let owner = UUID()
        let range = ProgressDateRange(period: .week, anchor: date(2026, 11, 1), calendar: calendar)
        let monday = date(2026, 10, 26), wednesday = date(2026, 10, 28), sunday = date(2026, 11, 1)
        let missing = DailySummary(date: wednesday, totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
        let nutrition = ProgressNutritionOverview(
            summaries: [summary(owner, monday, calories: 0), missing, summary(owner, sunday, calories: 2400)], periodDays: 7
        )
        let steps = StepCountSnapshot(range: range.interval, buckets: [
            StepCountBucket(date: monday, steps: 2000), StepCountBucket(date: wednesday, steps: 0)
        ], updatedAt: sunday)
        let workouts = HealthWorkoutSnapshot(range: range.interval, workouts: [
            HealthWorkoutSummary(id: UUID(), startDate: sunday, title: "Løping", duration: 1800),
            HealthWorkoutSummary(id: UUID(), startDate: sunday.addingTimeInterval(-3600), title: "Styrke", duration: 2700)
        ])
        let overview = ProgressWeekOverview(range: range, nutrition: nutrition, steps: steps, workouts: workouts, calendar: calendar)
        #expect(overview.days.map(\.calories) == [0, nil, nil, nil, nil, nil, 2400])
        #expect(overview.days.map(\.steps) == [2000, nil, 0, nil, nil, nil, nil])
        #expect(overview.days.last?.workouts.map(\.title) == ["Løping", "Styrke"])
        #expect(overview.totalCalories == 2400 && overview.averageCalories == 1200)
        #expect(overview.totalSteps == steps.count && overview.averageSteps == 1000)
        #expect(overview.loggedDays == 2 && overview.workoutCount == 2)

        let next = ProgressDateRange(period: .week, anchor: date(2026, 11, 2), calendar: calendar)
        let later = ProgressWeekOverview(range: next, nutrition: nutrition, steps: steps, workouts: workouts, calendar: calendar)
        #expect(later.totalSteps == nil && later.totalCalories == nil && later.workoutCount == 0)
        #expect(later.days.allSatisfy { $0.steps == nil && $0.calories == nil && $0.workouts.isEmpty })
    }

    @Test func monthNavigationClampsShortMonthsAndRestoresThePreferredDay() {
        let model = ProgressViewModel(repository: PeriodRepository(calendar: calendar), calendar: calendar,
                                      now: { self.date(2028, 1, 31) })
        model.selectPeriod(.month)
        model.movePeriod(by: 1)
        model.selectPeriod(.day)
        #expect(model.dateRange.interval.start == calendar.startOfDay(for: date(2028, 2, 29)))
        model.goToCurrentPeriod()
        #expect(model.dateRange.interval.start == calendar.startOfDay(for: date(2028, 1, 31)))

        model.selectPeriod(.month)
        model.movePeriod(by: 1)
        model.movePeriod(by: 1)
        model.selectPeriod(.day)
        #expect(model.dateRange.interval.start == calendar.startOfDay(for: date(2028, 3, 31)))
    }

    @Test func weekNavigationPreservesWeekdayAndCurrentPeriodKeepsTheSelectedScale() {
        let today = date(2026, 12, 30)
        let model = ProgressViewModel(repository: PeriodRepository(calendar: calendar), calendar: calendar, now: { today })
        #expect(model.isCurrentPeriod)
        model.movePeriod(by: 1)
        #expect(!model.isCurrentPeriod)
        model.selectPeriod(.day)
        #expect(model.dateRange.interval.start == calendar.startOfDay(for: date(2027, 1, 6)))
        model.selectPeriod(.week)
        model.goToCurrentPeriod()
        #expect(model.period == .week)
        #expect(model.isCurrentPeriod)
        model.selectPeriod(.day)
        #expect(model.dateRange.interval.start == calendar.startOfDay(for: today))
    }

    @Test func oldPeriodResponseCannotOverwriteNewSelection() async throws {
        let repository = PeriodRepository(calendar: calendar)
        repository.delay = true
        let model = ProgressViewModel(repository: repository, calendar: calendar, now: { self.date(2026, 11, 6) })
        let owner = UUID()
        let first = Task { await model.load(userId: owner) }
        try await waitUntil { repository.pending.count == 1 }
        model.selectPeriod(.month)
        let current = Task { await model.load(userId: owner) }
        try await waitUntil { repository.pending.count == 2 }
        repository.pending[1].resume(returning: DailySummary.summaries(userId: owner, dates: repository.dates[1], logs: [], calendar: calendar))
        await current.value
        repository.pending[0].resume(returning: [summary(owner, date(2026, 11, 6), calories: 900)])
        await first.value
        #expect(model.period == .month)
        #expect(model.summaries.count == 30)
        #expect(model.overview.averageCalories == nil)
    }

    @Test func weightSparklineUsesRealPointsAndKeepsOwnersAndPeriodSeparate() {
        let owner = UUID(), other = UUID()
        let range = ProgressDateRange(period: .week, anchor: date(2026, 11, 6), calendar: calendar)
        let older = WeightEntry(userId: owner, date: date(2026, 10, 20), weightKg: 75)
        let first = WeightEntry(userId: owner, date: date(2026, 11, 3), weightKg: 74)
        let last = WeightEntry(userId: owner, date: date(2026, 11, 5), weightKg: 73.8)
        let future = WeightEntry(userId: owner, date: date(2026, 11, 12), weightKg: 72)
        let foreign = WeightEntry(userId: other, date: date(2026, 11, 6), weightKg: 90)
        let invalid = WeightEntry(userId: owner, date: date(2026, 11, 6), weightKg: .infinity)
        let result = ProgressWeightOverview(entries: [future, older, foreign, last, invalid, first], range: range.interval, owner: owner)
        #expect(result.latest?.id == last.id)
        #expect(result.points.map(\.id) == [first.id, last.id])
        #expect(result.chartLowerBound < 73.8 && result.chartUpperBound > 74)
        let fallback = ProgressWeightOverview(entries: [older], range: range.interval, owner: owner)
        #expect(fallback.latest?.id == older.id)
        #expect(fallback.points.isEmpty)
        #expect(fallback.showsEarlierMeasurement)
        #expect(!result.showsEarlierMeasurement)
    }

    @Test func profileResetClearsWeightAndNutritionPresentation() async {
        let repository = PeriodRepository(calendar: calendar)
        let model = ProgressViewModel(repository: repository, calendar: calendar, now: { self.date(2026, 11, 6) })
        let owner = UUID()
        await model.load(userId: owner)
        model.updateWeights([WeightEntry(userId: owner, date: date(2026, 11, 5), weightKg: 74)], owner: owner)
        #expect(model.weightOverview.latest != nil)
        model.selectPeriod(.month)
        model.reset()
        #expect(model.period == .week)
        #expect(model.weightOverview.latest == nil && model.overview.averageCalories == nil)
    }

    @Test func compactWeightUsesMostRecentSourceAndKeepsSeriesSeparate() {
        let owner = UUID()
        let range = ProgressDateRange(period: .week, anchor: date(2026, 11, 6), calendar: calendar).interval
        let local = ProgressWeightOverview(
            entries: [WeightEntry(userId: owner, date: date(2026, 11, 5), weightKg: 74)],
            range: range,
            owner: owner
        )
        let newer = ProgressWeightMeasurement(id: UUID(), date: date(2026, 11, 6), weightKg: 72.8)
        let older = ProgressWeightMeasurement(id: UUID(), date: date(2026, 11, 2), weightKg: 73)
        let health = ProgressWeightOverview(latest: newer, points: [older, newer], source: .appleHealth)
        #expect(local.showingLatest(with: health) == health)
        #expect(local.showingLatest(with: nil) == local)
        let oldHealth = ProgressWeightOverview(latest: older, points: [older], source: .appleHealth)
        #expect(local.showingLatest(with: oldHealth) == local)
    }

    private func summary(_ owner: UUID, _ date: Date, calories: Float) -> DailySummary {
        let log = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                          loggedDate: date, calories: calories, proteinG: calories / 10, carbsG: 0, fatG: 0)
        return DailySummary(date: date, totalCalories: calories, totalProtein: calories / 10, totalCarbs: 0, totalFat: 0, logs: [log])
    }
    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Timed out waiting for repository")
    }
}

@MainActor
private final class PeriodRepository: FoodLogRepository {
    let calendar: Calendar
    var dates: [[Date]] = []
    var delay = false
    var pending: [CheckedContinuation<[DailySummary], Error>] = []
    init(calendar: Calendar) { self.calendar = calendar }
    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary] {
        self.dates.append(dates)
        if delay { return try await withCheckedThrowingContinuation { pending.append($0) } }
        return DailySummary.summaries(userId: userId, dates: dates, logs: [], calendar: calendar)
    }
    func saveLogs(_ logs: [FoodLog]) async throws {}
    func deleteLogs(_ ids: [UUID]) async throws {}
    func saveLog(_ log: FoodLog) async throws {}
    func deleteLog(_ id: UUID) async throws {}
    func getAllLogs(userId: UUID) async -> [FoodLog] { [] }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary.summaries(userId: userId, dates: [date], logs: [], calendar: calendar)[0]
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
    func getProduct(_ id: UUID) async -> Product? { nil }
}
