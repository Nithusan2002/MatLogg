import Foundation

protocol FoodLogRepository {
    func saveLogs(_ logs: [FoodLog]) async throws
    func deleteLogs(_ ids: [UUID]) async throws
    func saveLog(_ log: FoodLog) async throws
    func deleteLog(_ id: UUID) async throws
    func loadLoggingDates(userId: UUID) async throws -> [Date]
    func loadAllLogs(userId: UUID) async throws -> [FoodLog]
    func loadLogs(userId: UUID, from start: Date, before end: Date) async throws -> [FoodLog]
    func loadSummary(userId: UUID, date: Date) async throws -> DailySummary
    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary]
    func getProduct(_ id: UUID) async throws -> Product?
    func getProducts(_ ids: Set<UUID>) async throws -> [UUID: Product]
}

extension FoodLogRepository {
    func loadLogs(userId: UUID, from start: Date, before end: Date) async throws -> [FoodLog] {
        try await loadAllLogs(userId: userId).filter { $0.loggedDate >= start && $0.loggedDate < end }
    }

    func loadLoggingDates(userId: UUID) async throws -> [Date] {
        try await loadAllLogs(userId: userId).filter { $0.userId == userId }.map(\.loggedDate)
    }

    func loadSummary(userId: UUID, date: Date) async throws -> DailySummary {
        guard let summary = try await loadSummaries(userId: userId, dates: [date]).first else {
            throw DatabaseServiceError.unavailable
        }
        return summary
    }

    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary] {
        let logs = try await loadAllLogs(userId: userId)
        return DailySummary.summaries(userId: userId, dates: dates, logs: logs)
    }

    func getProducts(_ ids: Set<UUID>) async throws -> [UUID: Product] {
        var products: [UUID: Product] = [:]
        for id in ids { products[id] = try await getProduct(id) }
        return products
    }
}

extension DailySummary {
    nonisolated static func summaries(userId: UUID, dates: [Date], logs: [FoodLog], calendar: Calendar = .current) -> [DailySummary] {
        let grouped = Dictionary(grouping: logs.filter { $0.userId == userId }) {
            calendar.startOfDay(for: $0.loggedDate)
        }
        return dates.map { date in
            let day = calendar.startOfDay(for: date)
            let entries = (grouped[day] ?? []).sorted { $0.loggedTime < $1.loggedTime }
            let totals = NutritionCalculator.totals(for: entries)
            return DailySummary(date: day, totalCalories: totals.calories, totalProtein: totals.protein,
                                totalCarbs: totals.carbs, totalFat: totals.fat, logs: entries)
        }
    }
}

extension DatabaseService: FoodLogRepository {}
