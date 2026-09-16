//
//  MatLoggTests.swift
//  MatLoggTests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import Testing
import Foundation
@testable import MatLogg

struct MatLoggTests {
    @Test func appTabsHaveStableFiveTabOrder() {
        #expect(AppTab.allCases == [.home, .search, .add, .progress, .profile])
    }

    @Test @MainActor func mealPresentationContainsEverySupportedMealOnce() {
        #expect(MealPresentation.all.map(\.key) == ["frokost", "lunsj", "middag", "snacks"])
        #expect(Set(MealPresentation.all.map(\.id)).count == 4)
        #expect(MealPresentation.all.last?.title == "Kveldsmat")
        #expect(LogSummaryService.title(for: "snacks") == "Kveldsmat")
    }

    @Test func mealGroupingKeepsCanonicalStorageOrder() {
        let userId = UUID()
        let productId = UUID()
        let now = Date()
        let logs = ["snacks", "frokost", "middag"].map { meal in
            FoodLog(
                userId: userId,
                productId: productId,
                mealType: meal,
                amountG: 100,
                loggedDate: now,
                loggedTime: now,
                calories: 100,
                proteinG: 10,
                carbsG: 10,
                fatG: 10
            )
        }

        let grouped = LogSummaryService.groupedLogs(logs: logs) { _ in "Test" }
        #expect(grouped.map(\.mealType) == ["frokost", "middag", "snacks"])
    }

    @Test func goalCalculatorFallsBackWhenMissingData() async throws {
        let input = GoalCalculationInput(
            weightKg: nil,
            heightCm: nil,
            ageYears: nil,
            gender: nil,
            activity: .moderat,
            intent: .maintain,
            pace: .calm
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories == 2000)
    }
    
    @Test func goalCalculatorAdjustsForIntentAndPace() async throws {
        let input = GoalCalculationInput(
            weightKg: 80,
            heightCm: 180,
            ageYears: 30,
            gender: .mann,
            activity: .moderat,
            intent: .lose,
            pace: .standard
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories < result.baselineCalories)
    }
    
    @Test func goalCalculatorClampsExtremes() async throws {
        let input = GoalCalculationInput(
            weightKg: 30,
            heightCm: 140,
            ageYears: 80,
            gender: .kvinne,
            activity: .lav,
            intent: .lose,
            pace: .fast
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result.suggestedCalories >= 1200)
    }
    
    @Test func backoffRespectsBounds() async throws {
        let first = Backoff.nextDelay(attempt: 1)
        let later = Backoff.nextDelay(attempt: 6)
        #expect(first >= 10)
        #expect(later <= 6 * 60 * 60)
        #expect(later >= first)
    }
    
    @Test func inFlightResetsToPending() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 150,
            carbsTargetG: 250,
            fatTargetG: 65
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        let target = pending.first(where: { $0.entityId == goal.id.uuidString })
        #expect(target != nil)
        guard let event = target else { return }
        #expect(event.type == "goal.set")
        #expect(event.schemaVersion == 1)
        let payload = try JSONSerialization.jsonObject(with: event.payload) as? [String: Any]
        #expect(payload?["kcalTarget"] as? Int == 2000)
        #expect(payload?["proteinTarget"] as? Double == 150)
        await db.markEventsInFlight([event.eventId])
        await db.resetInFlightEvents()
        let pendingAfterReset = await db.fetchPendingEvents(limit: 50)
        #expect(pendingAfterReset.contains(where: { $0.eventId == event.eventId }))
    }
    
    @Test func retryBackoffSkipsUntilReady() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2100,
            proteinTargetG: 140,
            carbsTargetG: 260,
            fatTargetG: 70
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        guard let first = pending.first(where: { $0.entityId == goal.id.uuidString }) else {
            #expect(false)
            return
        }
        await db.markEventForRetry(first.eventId, error: "test", backoffSeconds: 60)
        let pendingAfter = await db.fetchPendingEvents(limit: 50)
        #expect(!pendingAfter.contains(where: { $0.eventId == first.eventId }))
    }
}

@MainActor
struct LogViewModelTests {
    @Test func loggingCalculatesNutritionAndPersistsThroughRepository() async {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let product = Product(
            name: "Testvare",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 50,
            mealType: "lunsj",
            userId: userId
        )

        #expect(succeeded)
        #expect(repository.savedLogs.count == 1)
        #expect(repository.savedLogs.first?.userId == userId)
        #expect(repository.savedLogs.first?.calories == 100)
        #expect(repository.savedLogs.first?.proteinG == 5)
    }

    @Test func repositoryFailureBecomesViewModelErrorState() async {
        let repository = FoodLogRepositorySpy()
        repository.saveError = TestRepositoryError.saveFailed
        let viewModel = LogViewModel(repository: repository)
        let product = Product(
            name: "Testvare",
            caloriesPer100g: 100,
            proteinGPer100g: 1,
            carbsGPer100g: 1,
            fatGPer100g: 1
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 100,
            mealType: "middag",
            userId: UUID()
        )

        #expect(!succeeded)
        #expect(viewModel.errorMessage?.hasPrefix("Kunne ikke lagre logging:") == true)
    }

    @Test func undoDeletesTheLatestMatchingLog() async {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let productId = UUID()
        let day = Date()
        let older = makeLog(userId: userId, productId: productId, date: day.addingTimeInterval(-60))
        let latest = makeLog(userId: userId, productId: productId, date: day)
        repository.logs = [older, latest]

        let succeeded = await viewModel.undoLatestLog(
            productId: productId,
            mealType: "lunsj",
            amountG: 100,
            userId: userId,
            date: day
        )

        #expect(succeeded)
        #expect(repository.deletedIds == [latest.id])
    }

    private func makeLog(userId: UUID, productId: UUID, date: Date) -> FoodLog {
        FoodLog(
            userId: userId,
            productId: productId,
            mealType: "lunsj",
            amountG: 100,
            loggedDate: date,
            loggedTime: date,
            calories: 100,
            proteinG: 1,
            carbsG: 1,
            fatG: 1
        )
    }
}

private enum TestRepositoryError: Error {
    case saveFailed
}

private final class FoodLogRepositorySpy: FoodLogRepository {
    var savedLogs: [FoodLog] = []
    var deletedIds: [UUID] = []
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var saveError: Error?

    func saveLog(_ log: FoodLog) async throws {
        if let saveError { throw saveError }
        savedLogs.append(log)
    }

    func deleteLog(_ id: UUID) async throws {
        deletedIds.append(id)
    }

    func getAllLogs(userId: UUID) async -> [FoodLog] {
        logs.filter { $0.userId == userId }
    }

    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        let matching = logs.filter {
            $0.userId == userId && Calendar.current.isDate($0.loggedDate, inSameDayAs: date)
        }
        return summary(date: date, logs: matching)
    }

    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }

    func getProduct(_ id: UUID) -> Product? {
        products[id]
    }

    private func summary(date: Date, logs: [FoodLog]) -> DailySummary {
        DailySummary(
            date: date,
            totalCalories: logs.reduce(0) { $0 + $1.calories },
            totalProtein: logs.reduce(0) { $0 + $1.proteinG },
            totalCarbs: logs.reduce(0) { $0 + $1.carbsG },
            totalFat: logs.reduce(0) { $0 + $1.fatG },
            logs: logs
        )
    }
}

@MainActor
struct HealthProfileViewModelTests {
    @Test func savingGoalUpdatesPublishedGoal() async {
        let repository = HealthProfileRepositorySpy()
        let viewModel = HealthProfileViewModel(
            repository: repository,
            personalDetailsStore: PersonalDetailsStoreSpy()
        )
        let goal = Goal(
            userId: UUID(),
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 120,
            carbsTargetG: 250,
            fatTargetG: 70
        )

        let succeeded = await viewModel.saveGoal(goal)

        #expect(succeeded)
        #expect(viewModel.currentGoal?.id == goal.id)
        #expect(repository.savedGoals.map(\.id) == [goal.id])
    }

    @Test func weightFromAnotherUserCannotBeDeleted() async {
        let repository = HealthProfileRepositorySpy()
        let viewModel = HealthProfileViewModel(
            repository: repository,
            personalDetailsStore: PersonalDetailsStoreSpy()
        )
        let entry = WeightEntry(userId: UUID(), date: Date(), weightKg: 75)

        let succeeded = await viewModel.deleteWeight(entry, userId: UUID())

        #expect(!succeeded)
        #expect(repository.deletedWeightIds.isEmpty)
    }
}

private final class HealthProfileRepositorySpy: HealthProfileRepository {
    var savedGoals: [Goal] = []
    var deletedWeightIds: [UUID] = []
    var weights: [WeightEntry] = []

    func saveGoal(_ goal: Goal) async throws {
        savedGoals.append(goal)
    }

    func latestGoal(userId: UUID) async -> Goal? {
        savedGoals.last { $0.userId == userId }
    }

    func saveWeightEntry(_ entry: WeightEntry) async throws {
        weights.append(entry)
    }

    func deleteWeightEntry(_ id: UUID) async throws {
        deletedWeightIds.append(id)
    }

    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        weights.filter { $0.userId == userId }
    }
}

private final class PersonalDetailsStoreSpy: PersonalDetailsStore {
    var details: PersonalDetails = .empty

    func load() -> PersonalDetails {
        details
    }

    func save(_ details: PersonalDetails) throws {
        self.details = details
    }
}

@MainActor
struct AuthViewModelTests {
    @Test func sessionRequiresBothStoredUserAndToken() {
        let user = makeUser()
        let incompleteStore = AuthSessionStoreSpy(user: user, token: nil)

        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user),
            sessionStore: incompleteStore
        )

        #expect(viewModel.currentUser == nil)
        if case .notAuthenticated = viewModel.authState {
            #expect(true)
        } else {
            #expect(false)
        }
    }

    @Test func loginPersistsSessionAndAuthenticatesUser() async {
        let user = makeUser()
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user, token: "test-token"),
            sessionStore: store
        )

        await viewModel.login(email: user.email, password: "password")

        #expect(viewModel.currentUser?.id == user.id)
        #expect(store.user?.id == user.id)
        #expect(store.token == "test-token")
        #expect(!viewModel.isLoading)
    }

    private func makeUser() -> User {
        User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            authProvider: "email",
            createdAt: Date()
        )
    }
}

private final class AuthAPIClientSpy: AuthAPIClient {
    let user: User
    let token: String

    init(user: User, token: String = "token") {
        self.user = user
        self.token = token
    }

    func loginEmail(email: String, password: String) async throws -> (User, String) {
        (user, token)
    }

    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, String) {
        (user, token)
    }
}

private final class AuthSessionStoreSpy: AuthSessionStore {
    var user: User?
    var token: String?

    init(user: User? = nil, token: String? = nil) {
        self.user = user
        self.token = token
    }

    func storeUser(_ user: User) {
        self.user = user
    }

    func getStoredUser() -> User? {
        user
    }

    func storeToken(_ token: String) {
        self.token = token
    }

    func getStoredToken() -> String? {
        token
    }

    func clearStoredCredentials() {
        user = nil
        token = nil
    }
}

@MainActor
struct PreferencesViewModelTests {
    @Test func enablingSafeModeAlwaysHidesCaloriesAndGoals() {
        let suiteName = "PreferencesViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let viewModel = PreferencesViewModel(defaults: defaults)
        viewModel.safeModeHideCalories = false
        viewModel.safeModeHideGoals = false

        viewModel.safeModeEnabled = true

        #expect(viewModel.safeModeHideCalories)
        #expect(viewModel.safeModeHideGoals)
    }
}
