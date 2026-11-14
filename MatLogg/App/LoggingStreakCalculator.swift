import Foundation

/// Counts recorded calendar days, independently of the date browsed on Home.
nonisolated enum LoggingStreakCalculator {
    static func count(dates: [Date], now: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: now)
        let days = Set(dates.map { calendar.startOfDay(for: $0) }.filter { $0 <= today })
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
        var day = days.contains(today) ? today : yesterday
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
