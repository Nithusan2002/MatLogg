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
    private static let e2eProductId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private static let e2eEventId = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

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

    @Test func restartRecoversInFlightEventWithStableId() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggSyncRestart-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("restart.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        var store: LocalStore? = LocalStore(databaseURL: databaseURL)
        let goal = Goal(
            userId: UUID(),
            goalType: "maintain",
            dailyCalories: 2200,
            proteinTargetG: 150,
            carbsTargetG: 275,
            fatTargetG: 70
        )
        try store?.saveGoal(goal)

        let created = try #require(store?.fetchPendingEvents(limit: 10).first)
        store?.markEventsInFlight([created.eventId])
        #expect(store?.fetchPendingEvents(limit: 10).isEmpty == true)

        store = nil
        let reopenedStore = LocalStore(databaseURL: databaseURL)
        let recovered = try #require(
            reopenedStore.fetchPendingEvents(limit: 10)
                .first(where: { $0.entityId == goal.id.uuidString })
        )

        #expect(recovered.eventId == created.eventId)
        #expect(recovered.status == .pending)
        #expect(recovered.attemptCount == 1)
        #expect(recovered.type == "goal.set")
        #expect(recovered.payload == created.payload)
    }

    @Test func swiftClientSyncsThroughHTTPToPostgres() async throws {
        #if MATLOGG_SYNC_E2E
        let serverURL = URL(string: "http://127.0.0.1:4000")!
        var loginRequest = URLRequest(url: serverURL.appendingPathComponent("auth/dev-login"))
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": "ios-client-e2e@integration.matlogg"
        ])
        let (loginData, loginResponse) = try await URLSession.shared.data(for: loginRequest)
        #expect((loginResponse as? HTTPURLResponse)?.statusCode == 201)

        struct LoginResponse: Decodable { let accessToken: String }
        let token = try JSONDecoder().decode(LoginResponse.self, from: loginData).accessToken
        let api = APIService(
            baseURL: serverURL.appendingPathComponent("v1").absoluteString,
            accessTokenProvider: { token },
            syncEnabled: { true }
        )
        let payload = try JSONSerialization.data(withJSONObject: [
            "id": Self.e2eProductId.uuidString,
            "name": "iOS E2E-produkt",
            "brand": "MatLogg test",
            "nutrientsPer100g": ["kcal": 42, "protein": 1, "carbs": 9, "fat": 0],
            "source": "user"
        ])
        let event = SyncEvent(
            eventId: Self.e2eEventId,
            type: "product.upsert",
            createdAt: Date(),
            entityId: Self.e2eProductId.uuidString,
            schemaVersion: 1,
            payload: payload,
            status: .pending,
            attemptCount: 0,
            lastAttemptAt: nil,
            nextRetryAt: nil,
            lastError: nil
        )

        let first = try await api.uploadEvents([event])
        #expect(first.ackedEventIds == [Self.e2eEventId])
        #expect(first.rejected.isEmpty)

        let replay = try await api.uploadEvents([event])
        #expect(replay.ackedEventIds == [Self.e2eEventId])
        #expect(replay.rejected.isEmpty)
        #endif
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

    @Test func updatingScannedProductPreservesExistingMealLog() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let product = Product(
            name: "Gjenskannet testvare",
            barcodeEan: "test-\(UUID().uuidString)",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )
        let log = FoodLog(
            userId: userId,
            productId: product.id,
            mealType: "lunsj",
            amountG: 100,
            loggedDate: Calendar.current.startOfDay(for: Date()),
            calories: 200,
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )

        try await db.saveProduct(product)
        try await db.saveLog(log)
        try await db.saveProduct(product)

        let summary = await db.getTodaysSummary(userId: userId)
        #expect(summary.logs.contains { $0.id == log.id && $0.mealType == "lunsj" })
    }

    @Test func localDatabaseUsesLatestFormalSchemaVersion() async {
        let version = await DatabaseService.shared.localSchemaVersion()
        #expect(version == LocalStore.latestSchemaVersion)
    }

    @Test func resetAllDataClearsDomainTablesAndSyncQueue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(databaseURL: directory.appendingPathComponent("reset.sqlite"))
        let userId = UUID()
        let product = Product(name: "Slettes", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 1)
        try store.saveProduct(product)
        try store.saveGoal(Goal(userId: userId, goalType: "maintain", dailyCalories: 2000, proteinTargetG: 100, carbsTargetG: 200, fatTargetG: 60))
        #expect(store.pendingSyncCount() > 0)

        try store.resetAllData()

        #expect(store.getProduct(product.id) == nil)
        #expect(store.getLatestGoal(userId: userId) == nil)
        #expect(store.pendingSyncCount() == 0)
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

    @Test func debugSessionKeepsSameIdentityAcrossAppRestarts() {
        let first = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: makeUser()),
            sessionStore: AuthSessionStoreSpy()
        )
        let restarted = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: makeUser()),
            sessionStore: AuthSessionStoreSpy()
        )

        first.enableDebugSession()
        restarted.enableDebugSession()

        #expect(first.currentUser?.id == restarted.currentUser?.id)
        #expect(first.currentUser?.authProvider == "debug")
    }

    @Test func successfulAccountDeletionClearsLocalDataAndCredentials() async {
        let user = makeUser()
        let api = AuthAPIClientSpy(user: user)
        let store = AuthSessionStoreSpy(user: user, token: "token")
        let resetter = LocalDataResetterSpy()
        let viewModel = AuthViewModel(apiClient: api, sessionStore: store, localDataResetter: resetter)

        let succeeded = await viewModel.deleteAccount()

        #expect(succeeded)
        #expect(api.deleteCallCount == 1)
        #expect(resetter.resetCallCount == 1)
        #expect(store.user == nil)
        #expect(store.token == nil)
    }

    @Test func failedAccountDeletionPreservesLocalDataAndSession() async {
        let user = makeUser()
        let api = AuthAPIClientSpy(user: user)
        api.deleteError = TestRepositoryError.saveFailed
        let store = AuthSessionStoreSpy(user: user, token: "token")
        let resetter = LocalDataResetterSpy()
        let viewModel = AuthViewModel(apiClient: api, sessionStore: store, localDataResetter: resetter)

        let succeeded = await viewModel.deleteAccount()

        #expect(!succeeded)
        #expect(resetter.resetCallCount == 0)
        #expect(store.user?.id == user.id)
        #expect(store.token == "token")
        #expect(viewModel.errorMessage != nil)
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
    var deleteCallCount = 0
    var deleteError: Error?

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

    func deleteAccount() async throws -> AccountDeletionReceipt {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        return AccountDeletionReceipt(
            code: "ACCOUNT_PENDING_DELETION",
            message: "Kontoen er markert for sletting",
            permanentDeletionAt: Date().addingTimeInterval(30 * 86_400)
        )
    }
}

private final class LocalDataResetterSpy: LocalDataResetting {
    var resetCallCount = 0

    func resetAllLocalData() async throws {
        resetCallCount += 1
    }
}

@MainActor
struct AppStateTests {
    @Test func defaultMealFollowsLocalHourBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: 16)
        func date(_ hour: Int) -> Date {
            var components = base
            components.hour = hour
            return calendar.date(from: components)!
        }

        #expect(AppState.defaultMealType(at: date(5), calendar: calendar) == "frokost")
        #expect(AppState.defaultMealType(at: date(10), calendar: calendar) == "frokost")
        #expect(AppState.defaultMealType(at: date(11), calendar: calendar) == "lunsj")
        #expect(AppState.defaultMealType(at: date(16), calendar: calendar) == "middag")
        #expect(AppState.defaultMealType(at: date(21), calendar: calendar) == "snacks")
        #expect(AppState.defaultMealType(at: date(4), calendar: calendar) == "snacks")
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

@MainActor
struct ManualProductViewModelTests {
    @Test @MainActor func rejectsProductNameAboveMaximumLength() async {
        var didSave = false
        let viewModel = ManualProductViewModel(barcode: nil) { _ in
            didSave = true
        }
        viewModel.name = String(repeating: "a", count: ManualProductViewModel.maximumNameLength + 1)
        viewModel.calories = "100"
        viewModel.protein = "10"
        viewModel.carbs = "20"
        viewModel.fat = "5"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(didSave == false)
        #expect(viewModel.errorMessage?.contains("maksimalt") == true)
    }

    @Test func savesUserEnteredNutritionWithoutEstimatingValues() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: "7038010054821") { product in
            savedProducts.append(product)
        }
        viewModel.name = "  Testbrød  "
        viewModel.calories = "241"
        viewModel.protein = "8,5"
        viewModel.carbs = "42.25"
        viewModel.fat = "3"

        let product = await viewModel.save()

        #expect(product?.name == "Testbrød")
        #expect(product?.barcodeEan == "7038010054821")
        #expect(product?.nutritionSource == .user)
        #expect(product?.verificationStatus == .unverified)
        #expect(product?.proteinGPer100g == 8.5)
        #expect(product?.carbsGPer100g == 42.25)
        #expect(savedProducts.map(\.id) == [product?.id].compactMap { $0 })
    }

    @Test func missingNutritionIsRejectedInsteadOfDefaultingToZero() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: nil) { product in
            savedProducts.append(product)
        }
        viewModel.name = "Testvare"
        viewModel.calories = "100"
        viewModel.protein = ""
        viewModel.carbs = "10"
        viewModel.fat = "5"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(savedProducts.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func impossibleMacroTotalIsRejected() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: nil) { product in
            savedProducts.append(product)
        }
        viewModel.name = "Testvare"
        viewModel.calories = "500"
        viewModel.protein = "50"
        viewModel.carbs = "50"
        viewModel.fat = "10"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(savedProducts.isEmpty)
        #expect(viewModel.errorMessage?.contains("ikke overstige 100") == true)
    }
}
