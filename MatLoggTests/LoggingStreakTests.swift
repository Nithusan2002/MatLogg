import Foundation
import Testing
@testable import MatLogg

struct LoggingStreakTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        return calendar
    }
    private func day(_ offset: Int) -> Date {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 3, day: 30, hour: 12))!
        return calendar.date(byAdding: .day, value: offset, to: anchor)!
    }
    private func count(_ offsets: [Int]) -> Int {
        LoggingStreakCalculator.count(dates: offsets.map(day), now: day(0), calendar: calendar)
    }

    @Test func countsCalendarDaysAcrossDaylightSavingAndIgnoresDuplicates() {
        #expect(count([]) == 0)
        #expect(count([0]) == 1)
        #expect(count([0, 0, -1, -2, -3]) == 4)
        #expect(count([-1, -2, -3]) == 3)
        #expect(count([-2, -3]) == 0)
        #expect(count([0, -2]) == 1)
        #expect(count([1, 2]) == 0)
        #expect(count([1, 0, -1]) == 2)
    }

    @Test func backfillRepairsGapAndMidnightRetainsYesterday() {
        #expect(count([0, -2, -3]) == 1)
        #expect(count([0, -1, -2, -3]) == 4)
        let dates = [day(0), day(-1)]
        #expect(LoggingStreakCalculator.count(dates: dates, now: day(1), calendar: calendar) == 2)
        #expect(LoggingStreakCalculator.count(dates: dates, now: day(2), calendar: calendar) == 0)
    }

    @MainActor
    @Test func localDatesAreOwnerScopedAndReflectDeletionAndHomeDateBrowsing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("streak.sqlite"))
        let repository = DatabaseService(store: store)
        let owner = UUID(), other = UUID()
        func log(_ owner: UUID, _ date: Date) -> FoodLog {
            FoodLog(userId: owner, productId: UUID(), mealType: "frokost", amountG: 60,
                    loggedDate: date, loggedTime: date, calories: 100, proteinG: 2, carbsG: 10, fatG: 3)
        }
        let yesterday = log(owner, day(-1))
        try store.saveLogs([log(owner, day(0)), yesterday, log(other, day(-2))])
        let model = HomeOverviewViewModel(repository: repository)
        await model.load(userId: owner, date: day(-5), now: day(0), calendar: calendar)
        #expect(model.loggingStreak == 2)
        try store.deleteLog(yesterday.id)
        await model.load(userId: owner, date: day(0), now: day(0), calendar: calendar)
        #expect(model.loggingStreak == 1)
        await model.load(userId: other, date: day(0), now: day(0), calendar: calendar)
        #expect(model.loggingStreak == 0)
        model.reset()
        #expect(model.loggingStreak == nil)
    }
}
