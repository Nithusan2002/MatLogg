import Foundation
import Testing
@testable import MatLogg

@MainActor
struct HistoryReadViewModelTests {
    @Test func firstFailureDoesNotPublishEmptySummaryAndRetryRecovers() async {
        let repo = HistoryReadRepository()
        let failing = LogViewModel(repository: repo)
        let owner = UUID(), date = Date()
        repo.fails = true
        await failing.loadSelectedSummary(userId: owner, date: date)
        #expect(failing.selectedSummary == nil)
        #expect(failing.summaryErrorMessage != nil)
        #expect(!failing.isSummaryLoading)
        repo.fails = false
        await failing.loadSelectedSummary(userId: owner, date: date)
        #expect(failing.selectedSummary?.logs.isEmpty == true)
        #expect(failing.summaryErrorMessage == nil)
    }

    @Test func refreshFailureKeepsPreviousHistoryButOwnerChangeClearsIt() async throws {
        let repo = HistoryReadRepository(), owner = UUID(), date = Date()
        repo.logs = [log(owner: owner, date: date)]
        let model = LogViewModel(repository: repo)
        await model.loadSelectedSummary(userId: owner, date: date)
        let initial = try #require(model.selectedSummary)
        repo.fails = true
        await model.loadSelectedSummary(userId: owner, date: date)
        #expect(model.selectedSummary?.logs.map(\.id) == initial.logs.map(\.id))
        #expect(model.selectedDay.summary?.totalCalories == initial.totalCalories)
        #expect(model.summaryErrorMessage != nil)
        await model.loadSelectedSummary(userId: UUID(), date: date)
        #expect(model.selectedSummary == nil)
        #expect(model.selectedDay.summary == nil)
    }

    @Test func olderFailureCannotOverwriteNewerSuccessfulDay() async throws {
        let repo = HistoryReadRepository(), owner = UUID(), date = Date()
        let model = LogViewModel(repository: repo)
        repo.suspends = true
        let first = Task { await model.loadSelectedSummary(userId: owner, date: date) }
        for _ in 0..<10_000 {
            if !repo.pending.isEmpty { break }
            await Task.yield()
        }
        try #require(!repo.pending.isEmpty)
        repo.suspends = false
        let next = date.addingTimeInterval(86_400)
        await model.loadSelectedSummary(userId: owner, date: next)
        repo.pending.removeFirst().resume(throwing: HistoryReadTestError.unavailable)
        await first.value
        #expect(model.summaryErrorMessage == nil)
        #expect(model.selectedSummary?.date == Calendar.current.startOfDay(for: next))
    }

    @Test func failedReadPreventsUndoAndCopyWrites() async {
        let repo = HistoryReadRepository(), owner = UUID(), date = Date()
        repo.fails = true
        let model = LogViewModel(repository: repo)
        #expect(await model.undoLatestLog(productId: UUID(), mealType: "frokost", amountG: 100, userId: owner) == false)
        #expect(await model.copyLogs(from: date, to: date, userId: owner) == false)
        #expect(repo.writes == 0)
        #expect(model.errorMessage != nil)
    }

    @Test func reuseRefreshFailureKeepsSuggestionAndStopsLogging() async throws {
        let repo = HistoryReadRepository(), owner = UUID(), date = Date()
        let product = Product(name: "QA", source: "manual", caloriesPer100g: 100,
                              proteinGPer100g: 10, carbsGPer100g: 10, fatGPer100g: 2)
        let previous = log(owner: owner, date: date.addingTimeInterval(-86_400), productId: product.id)
        repo.logs = [previous]
        repo.products = [product.id: product]
        let model = MealReuseViewModel(repository: repo, now: { date })
        await model.load(userId: owner, date: date)
        let suggestion = try #require(model.suggestions.first)
        repo.fails = true
        await model.load(userId: owner, date: date)
        #expect(model.suggestions.count == 1)
        #expect(model.errorMessage != nil)
        #expect(await model.log(suggestion) == false)
        #expect(repo.writes == 0)
    }

    #if os(iOS)
    @Test func unavailableDatabasePropagatesThroughRepository() async {
        let repository: any FoodLogRepository = DatabaseService(storeResult: .failure(HistoryReadTestError.unavailable))
        await #expect(throws: DatabaseServiceError.self) { try await repository.loadAllLogs(userId: UUID()) }
        await #expect(throws: DatabaseServiceError.self) {
            try await repository.loadLogs(userId: UUID(), from: .distantPast, before: .distantFuture)
        }
    }
    #endif

    private func log(owner: UUID, date: Date, productId: UUID = UUID()) -> FoodLog {
        FoodLog(userId: owner, productId: productId, mealType: "frokost", amountG: 100,
                loggedDate: date, loggedTime: date, calories: 100, proteinG: 10, carbsG: 10, fatG: 2)
    }
}

private enum HistoryReadTestError: Error { case unavailable }

@MainActor
private final class HistoryReadRepository: FoodLogRepository {
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var fails = false
    var suspends = false
    var pending: [CheckedContinuation<[DailySummary], Error>] = []
    var writes = 0
    func loadAllLogs(userId: UUID) async throws -> [FoodLog] {
        if fails { throw HistoryReadTestError.unavailable }
        return logs.filter { $0.userId == userId }
    }
    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary] {
        if suspends { return try await withCheckedThrowingContinuation { pending.append($0) } }
        return DailySummary.summaries(userId: userId, dates: dates, logs: try await loadAllLogs(userId: userId))
    }
    func getAllLogs(userId: UUID) async -> [FoodLog] { logs }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary.summaries(userId: userId, dates: [date], logs: logs)[0]
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
    func getProduct(_ id: UUID) async -> Product? { products[id] }
    func saveLog(_ log: FoodLog) async throws { writes += 1 }
    func saveLogs(_ logs: [FoodLog]) async throws { writes += 1 }
    func deleteLog(_ id: UUID) async throws { writes += 1 }
    func deleteLogs(_ ids: [UUID]) async throws { writes += 1 }
}
