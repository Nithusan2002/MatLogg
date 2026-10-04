import Foundation

protocol FoodLogRepository {
    func saveLogs(_ logs: [FoodLog]) async throws
    func deleteLogs(_ ids: [UUID]) async throws
    func saveLog(_ log: FoodLog) async throws
    func deleteLog(_ id: UUID) async throws
    func getAllLogs(userId: UUID) async -> [FoodLog]
    func getLogs(userId: UUID, from start: Date, before end: Date) async -> [FoodLog]
    func getSummary(userId: UUID, date: Date) async -> DailySummary
    func getTodaysSummary(userId: UUID) async -> DailySummary
    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary]
    func getProduct(_ id: UUID) async -> Product?
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product]
}

extension FoodLogRepository {
    func getLogs(userId: UUID, from start: Date, before end: Date) async -> [FoodLog] {
        await getAllLogs(userId: userId).filter { $0.loggedDate >= start && $0.loggedDate < end }
    }

    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary] {
        let logs = await getAllLogs(userId: userId)
        return DailySummary.summaries(userId: userId, dates: dates, logs: logs)
    }

    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        var products: [UUID: Product] = [:]
        for id in ids { products[id] = await getProduct(id) }
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
