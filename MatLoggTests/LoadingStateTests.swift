import Foundation
import Testing
@testable import MatLogg

@MainActor
struct LoadingStateTests {
    @Test func homeKeepsContentDuringRefreshAndRejectsOlderProductBatch() async throws {
        let repository = LoadingRepository()
        let model = HomeOverviewViewModel(repository: repository)
        let owner = UUID(), date = Date()
        #expect(model.isLoading)
        let first = Task { await model.load(userId: owner, date: date) }
        try await waitUntil { repository.summaryRequests.count == 1 }
        let item = product("Første vare")
        repository.summaryRequests[0].resume(returning: [summary(owner: owner, date: date, product: item)])
        try await waitUntil { repository.productRequests.count == 1 }
        let second = Task { await model.load(userId: owner, date: date) }
        try await waitUntil { repository.summaryRequests.count == 2 }
        let latest = product("Ny vare")
        repository.summaryRequests[1].resume(returning: [summary(owner: owner, date: date, product: latest)])
        try await waitUntil { repository.productRequests.count == 2 }
        repository.productRequests[1].resume(returning: [latest.id: latest])
        await second.value
        repository.productRequests[0].resume(returning: [item.id: item])
        await first.value
        #expect(model.overview.productNames[latest.id] == latest.name)
        #expect(model.products[item.id] == nil)
        #expect(!model.isLoading)
        #expect(repository.productRequests.count == 2)

        let refresh = Task { await model.load(userId: owner, date: date) }
        try await waitUntil { repository.summaryRequests.count == 3 }
        #expect(model.isLoading)
        #expect(model.overview.summary?.logs.first?.productId == latest.id)
        repository.summaryRequests[2].resume(throwing: DatabaseServiceError.unavailable)
        await refresh.value
        #expect(model.errorMessage != nil)
        #expect(model.overview.summary?.logs.first?.productId == latest.id)
        #expect(!model.isLoading)
    }

    @Test func progressUsesOneWeekRequestAndResetRejectsDelayedData() async throws {
        let repository = LoadingRepository()
        let model = ProgressViewModel(repository: repository)
        let first = Task { await model.load(userId: UUID()) }
        try await waitUntil { repository.summaryRequests.count == 1 }
        #expect(model.isLoading)
        #expect(repository.requestedDates[0].count == 7)
        #expect(repository.requestedDates[0] == repository.requestedDates[0].sorted())
        model.reset()
        let owner = UUID()
        let current = Task { await model.load(userId: owner) }
        try await waitUntil { repository.summaryRequests.count == 2 }
        repository.summaryRequests[1].resume(returning: DailySummary.summaries(userId: owner, dates: repository.requestedDates[1], logs: []))
        await current.value
        repository.summaryRequests[0].resume(throwing: DatabaseServiceError.unavailable)
        await first.value
        #expect(model.summaries.count == 7)
        #expect(model.errorMessage == nil)
        #expect(!model.isLoading)
    }

    @Test func savedMealsShowLoadingRetryAndRejectOlderSameOwnerResponse() async throws {
        let repository = LoadingRepository()
        let model = SavedMealsViewModel(savedMealRepository: repository, foodLogRepository: repository,
                                       photoRepository: LocalMealPhotoRepository())
        let owner = UUID()
        #expect(model.isLoading)
        let first = Task { await model.load(userId: owner) }
        try await waitUntil { repository.mealRequests.count == 1 }
        let second = Task { await model.load(userId: owner) }
        try await waitUntil { repository.mealRequests.count == 2 }
        repository.mealRequests[1].resume(returning: [])
        await second.value
        repository.mealRequests[0].resume(throwing: DatabaseServiceError.unavailable)
        await first.value
        #expect(model.loadError == nil)
        #expect(!model.isLoading)

        let failure = Task { await model.load(userId: owner) }
        try await waitUntil { repository.mealRequests.count == 3 }
        repository.mealRequests[2].resume(throwing: DatabaseServiceError.unavailable)
        await failure.value
        #expect(model.loadError != nil)
        let retry = Task { await model.load(userId: owner) }
        try await waitUntil { repository.mealRequests.count == 4 }
        repository.mealRequests[3].resume(returning: [])
        await retry.value
        #expect(model.loadError == nil)
        #expect(!model.isLoading)
    }

    @Test func scanHistoryRejectsResponseAfterResetAndReportsFailure() async throws {
        let repository = LoadingRepository()
        let model = ScanHistoryViewModel(repository: repository)
        let first = Task { await model.load(userId: UUID()) }
        try await waitUntil { repository.scanRequests.count == 1 }
        #expect(model.isLoading)
        model.reset()
        await model.load(userId: nil)
        repository.scanRequests[0].resume(returning: ScanHistorySnapshot(scans: [], products: [UUID(): product("Gammel profil")]))
        await first.value
        #expect(model.products.isEmpty)
        let retry = Task { await model.load(userId: UUID()) }
        try await waitUntil { repository.scanRequests.count == 2 }
        repository.scanRequests[1].resume(throwing: DatabaseServiceError.unavailable)
        await retry.value
        #expect(model.errorMessage != nil)
        #expect(!model.isLoading)
    }

    @Test func weekReadPreservesDayOrderOwnerTotalsAndSyncQueue() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("loading.sqlite"))
        let owner = UUID(), other = UUID(), item = product("Testvare")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        let older = try #require(calendar.date(byAdding: .day, value: -2, to: today))
        let first = summary(owner: owner, date: yesterday, product: item).logs[0]
        let foreign = summary(owner: other, date: yesterday, product: item).logs[0]
        try store.saveLogs([first, foreign])
        let count = store.pendingSyncCount()
        let repository = DatabaseService(store: store)
        let dates = [today, older, yesterday]
        let result = try await repository.loadSummaries(userId: owner, dates: dates)
        #expect(result.map(\.date) == dates)
        #expect(result[0].logs.isEmpty && result[1].logs.isEmpty)
        #expect(result[2].logs.map(\.id) == [first.id])
        #expect(result[2].totalCalories == store.getSummary(userId: owner, date: yesterday).totalCalories)
        #expect(store.pendingSyncCount() == count)
        #expect(try await repository.loadSummaries(userId: owner, dates: []).isEmpty)
    }

    @Test func healthResetRejectsDelayedGoalAndWeightResponses() async throws {
        let repository = LoadingHealthRepository()
        let model = HealthProfileViewModel(repository: repository)
        let owner = UUID()
        let goals = Task { await model.loadGoal(userId: owner) }
        let weights = Task { await model.loadWeightEntries(userId: owner) }
        try await waitUntil { repository.goalRequest != nil && repository.weightRequest != nil }
        #expect(model.isLoadingWeights)
        model.resetUserState()
        repository.goalRequest?.resume(returning: Goal(userId: owner, goalType: "maintain", dailyCalories: 2000,
            proteinTargetG: 100, carbsTargetG: 200, fatTargetG: 70))
        repository.weightRequest?.resume(returning: [WeightEntry(userId: owner, date: Date(), weightKg: 75)])
        await goals.value
        await weights.value
        #expect(model.currentGoal == nil)
        #expect(model.weightEntries.isEmpty)
        #expect(!model.isLoadingWeights)
    }

    private func product(_ name: String) -> Product {
        Product(name: name, caloriesPer100g: 100, proteinGPer100g: 2, carbsGPer100g: 10, fatGPer100g: 4)
    }

    private func summary(owner: UUID, date: Date, product: Product) -> DailySummary {
        let log = FoodLog(userId: owner, productId: product.id, mealType: "frokost", amountG: 100,
                          loggedDate: date, calories: 100, proteinG: 2, carbsG: 10, fatG: 4)
        return DailySummary.summaries(userId: owner, dates: [date], logs: [log])[0]
    }

    private func waitUntil(_ predicate: () -> Bool) async throws {
        for _ in 0..<200 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        try #require(predicate())
    }
}

@MainActor
private final class LoadingHealthRepository: HealthProfileRepository {
    var goalRequest: CheckedContinuation<Goal?, Never>?
    var weightRequest: CheckedContinuation<[WeightEntry], Never>?
    func latestGoal(userId: UUID) async -> Goal? {
        await withCheckedContinuation { goalRequest = $0 }
    }
    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        await withCheckedContinuation { weightRequest = $0 }
    }
    func saveGoal(_ goal: Goal) async throws {}
    func saveWeightEntry(_ entry: WeightEntry) async throws {}
    func deleteWeightEntry(_ id: UUID) async throws {}
}

@MainActor
private final class LoadingRepository: FoodLogRepository, SavedMealRepository, ScanHistoryRepository {
    var summaryRequests: [CheckedContinuation<[DailySummary], Error>] = []
    var requestedDates: [[Date]] = []
    var productRequests: [CheckedContinuation<[UUID: Product], Never>] = []
    var mealRequests: [CheckedContinuation<[SavedMeal], Error>] = []
    var scanRequests: [CheckedContinuation<ScanHistorySnapshot, Error>] = []
    func loadSummaries(userId: UUID, dates: [Date]) async throws -> [DailySummary] {
        requestedDates.append(dates)
        return try await withCheckedThrowingContinuation { summaryRequests.append($0) }
    }
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] {
        await withCheckedContinuation { productRequests.append($0) }
    }
    func loadSavedMeals(userId: UUID) async throws -> [SavedMeal] {
        try await withCheckedThrowingContinuation { mealRequests.append($0) }
    }
    func loadScanHistory(userId: UUID) async throws -> ScanHistorySnapshot {
        try await withCheckedThrowingContinuation { scanRequests.append($0) }
    }
    func getAllLogs(userId: UUID) async -> [FoodLog] { [] }
    func getSummary(userId: UUID, date: Date) async -> DailySummary { DailySummary.summaries(userId: userId, dates: [date], logs: [])[0] }
    func getTodaysSummary(userId: UUID) async -> DailySummary { DailySummary.summaries(userId: userId, dates: [Date()], logs: [])[0] }
    func getProduct(_ id: UUID) async -> Product? { nil }
    func saveLogs(_ logs: [FoodLog]) async throws {}
    func deleteLogs(_ ids: [UUID]) async throws {}
    func saveLog(_ log: FoodLog) async throws {}
    func deleteLog(_ id: UUID) async throws {}
    func getSavedMeals(userId: UUID) async -> [SavedMeal] { [] }
    func saveSavedMeal(_ meal: SavedMeal) async throws {}
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws {}
}
