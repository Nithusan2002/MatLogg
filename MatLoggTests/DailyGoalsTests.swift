import Foundation
import Testing
@testable import MatLogg

@MainActor
struct DailyGoalsTests {
    private func goal(userId: UUID = UUID()) -> Goal {
        Goal(userId: userId, goalType: "weight_loss", dailyCalories: 2137,
             proteinTargetG: 123.45678, carbsTargetG: 201.23456, fatTargetG: 68.98765,
             intent: .lose, pace: .standard, activityLevel: .hoy)
    }

    @Test func readsBooleanPresentationPreferencesFromLaunchConfiguration() {
        let suite = "DailyGoalsPreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.setVolatileDomain([
            "safeModeEnabled": "YES", "safeModeHideGoals": "YES", "safeModeHideCalories": "YES"
        ], forName: UserDefaults.argumentDomain)
        defer {
            defaults.removeVolatileDomain(forName: UserDefaults.argumentDomain)
            defaults.removePersistentDomain(forName: suite)
        }
        let preferences = PreferencesViewModel(defaults: defaults)
        #expect(preferences.safeModeEnabled)
        #expect(preferences.safeModeHideGoals)
        #expect(preferences.safeModeHideCalories)
    }

    @Test func unchangedSavePreservesExactValuesAndDoesNotEnqueueAnEvent() async {
        let repository = GoalRepositoryStub()
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        #expect(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false))
        #expect(vm.didSave)
        #expect(repository.saved.isEmpty)
        #expect(Float(vm.protein.replacingOccurrences(of: ",", with: ".")) == original.proteinTargetG)
    }

    @Test func editsPreserveOtherValuesAndMetadataAndPublishAfterSave() async {
        let repository = GoalRepositoryStub()
        let original = goal()
        var published: Goal?
        let vm = DailyGoalsViewModel(repository: repository) { published = $0 }
        vm.begin(goal: original, userId: original.userId)
        vm.protein = "134,75"
        #expect(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false))
        #expect(published?.proteinTargetG == 134.75)
        #expect(published?.carbsTargetG == original.carbsTargetG)
        #expect(published?.fatTargetG == original.fatTargetG)
        #expect(published?.dailyCalories == original.dailyCalories)
        #expect(published?.intent == original.intent)
        #expect(published?.pace == original.pace)
        #expect(published?.activityLevel == original.activityLevel)
        #expect(published?.userId == original.userId)
        #expect(repository.saved.count == 1)
    }

    @Test(arguments: ["", "0", "1199", "4501", "2000.5", "nan", "9999999999999999999999999"])
    func rejectsInvalidCalories(value: String) async {
        let repository = GoalRepositoryStub()
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        vm.calories = value
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false)))
        #expect(vm.errors[.calories] != nil)
        #expect(repository.saved.isEmpty)
    }

    @Test(arguments: ["", "-1", "nan", "inf", "1e40", "1e19", "ikke et tall"])
    func rejectsInvalidMacros(value: String) async {
        let repository = GoalRepositoryStub()
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        vm.protein = value
        vm.carbs = value
        vm.fat = value
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false)))
        #expect(vm.errors.count == 3)
        #expect(repository.saved.isEmpty)
    }

    @Test(arguments: [1200, 4500])
    func acceptsCalorieBoundariesAndZeroMacros(calories: Int) async {
        let repository = GoalRepositoryStub()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: nil, userId: UUID())
        vm.calories = String(calories)
        vm.protein = "0"
        vm.carbs = "0"
        vm.fat = "0"
        #expect(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false))
        #expect(repository.saved.last?.dailyCalories == calories)
    }

    @Test func failureRetainsDraftAndRetryPublishesOnlyAfterSuccess() async {
        let repository = GoalRepositoryStub()
        repository.shouldFail = true
        let original = goal()
        var publications = 0
        let vm = DailyGoalsViewModel(repository: repository) { _ in publications += 1 }
        vm.begin(goal: original, userId: original.userId)
        vm.calories = "2345"
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false)))
        #expect(vm.calories == "2345")
        #expect(vm.errorMessage != nil)
        #expect(!vm.isSaving && !vm.didSave)
        #expect(publications == 0)
        repository.shouldFail = false
        #expect(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false))
        #expect(publications == 1)
        #expect(repository.saved.count == 1)
    }

    @Test func repeatedSaveWhileSuspendedWritesOnce() async {
        let repository = GoalRepositoryStub()
        repository.suspend = true
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        vm.calories = "2345"
        let first = Task { await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false) }
        while repository.continuation == nil { await Task.yield() }
        #expect(vm.isSaving)
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false)))
        repository.continuation?.resume()
        #expect(await first.value)
        #expect(repository.saved.count == 1)
    }

    @Test func discardAndReopenRestoreOriginalWithoutWriting() {
        let repository = GoalRepositoryStub()
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        vm.calories = "2345"
        vm.discard()
        vm.begin(goal: original, userId: original.userId)
        #expect(vm.calories == "2137")
        #expect(repository.saved.isEmpty)
    }

    @Test func hiddenGoalsCannotSaveAndHiddenCaloriesArePreserved() async {
        let repository = GoalRepositoryStub()
        let original = goal()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: original, userId: original.userId)
        vm.calories = "9999"
        vm.protein = "100"
        #expect(!(await vm.save(hideGoals: true, hideCalories: false, safeModeEnabled: false)))
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: true)))
        #expect(repository.saved.isEmpty)
        #expect(await vm.save(hideGoals: false, hideCalories: true, safeModeEnabled: false))
        #expect(repository.saved.last?.dailyCalories == original.dailyCalories)
        #expect(repository.saved.last?.proteinTargetG == 100)
    }

    @Test func missingSessionAndMismatchedOwnerNeverReuseAnotherUsersGoal() async {
        let repository = GoalRepositoryStub()
        let vm = DailyGoalsViewModel(repository: repository)
        vm.begin(goal: goal(), userId: UUID())
        #expect(!vm.hasGoal && vm.calories.isEmpty)
        vm.begin(goal: nil, userId: nil)
        #expect(!(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false)))
        #expect(repository.saved.isEmpty)
    }

    @Test func suggestionRecalculatesFromStoredAgeAndOnlyAppliesToDraft() {
        let original = goal()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = calendar.date(byAdding: .year, value: -30, to: now)!
        let details = PersonalDetails(weightKg: 75, heightCm: 180, birthDate: birthDate, gender: .mann)
        let suggestionVM = GoalSuggestionViewModel(goal: original, details: details, now: now, calendar: calendar)
        #expect(suggestionVM.usesPersonalDetails)
        let initial = suggestionVM.suggestion.calories
        suggestionVM.activity = .veldigHoy
        #expect(suggestionVM.suggestion.calories != initial)
        let active = suggestionVM.suggestion.calories
        suggestionVM.intent = .gain
        #expect(suggestionVM.suggestion.calories != active)
        let gaining = suggestionVM.suggestion.calories
        suggestionVM.pace = .fast
        #expect(suggestionVM.suggestion.calories != gaining)
        let repository = GoalRepositoryStub()
        let editor = DailyGoalsViewModel(repository: repository)
        editor.begin(goal: original, userId: original.userId)
        #expect(editor.calories == "2137")
        editor.apply(suggestionVM.suggestion)
        #expect(editor.calories == String(suggestionVM.suggestion.calories))
        #expect(repository.saved.isEmpty)
    }

    @Test func invalidPersonalDetailsFallBackWithoutCrashing() {
        let details = PersonalDetails(weightKg: .infinity, heightCm: .nan, birthDate: Date())
        let vm = GoalSuggestionViewModel(goal: nil, details: details)
        #expect(!vm.usesPersonalDetails)
        #expect(GoalCalculator.calorieRange.contains(vm.suggestion.calories))
    }

    @Test func savedGoalAndSyncEventSurviveReopeningLocalStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("goals.sqlite")
        let userId = UUID()
        var eventId: UUID?
        do {
            let repository = LocalGoalRepository(store: LocalStore(databaseURL: url))
            let vm = DailyGoalsViewModel(repository: repository)
            vm.begin(goal: nil, userId: userId)
            vm.calories = "2100"
            vm.protein = "120,25"
            vm.carbs = "220,75"
            vm.fat = "70,125"
            #expect(await vm.save(hideGoals: false, hideCalories: false, safeModeEnabled: false))
            let events = repository.store.fetchPendingEvents(limit: 10)
            #expect(events.count == 1)
            eventId = events.first?.eventId
        }
        let reopened = LocalStore(databaseURL: url)
        let saved = try #require(reopened.getLatestGoal(userId: userId))
        #expect(saved.dailyCalories == 2100)
        #expect(saved.proteinTargetG == 120.25)
        #expect(saved.carbsTargetG == 220.75)
        #expect(saved.fatTargetG == 70.125)
        let event = try #require(reopened.fetchPendingEvents(limit: 10).first)
        #expect(event.eventId == eventId)
        #expect(event.type == "goal.set")
        #expect(event.entityId == saved.id.uuidString)
    }
}

@MainActor
private final class GoalRepositoryStub: GoalRepository {
    var saved: [Goal] = []
    var shouldFail = false
    var suspend = false
    var continuation: CheckedContinuation<Void, Never>?
    func saveGoal(_ goal: Goal) async throws {
        if suspend { await withCheckedContinuation { continuation = $0 } }
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        saved.append(goal)
    }
    func latestGoal(userId: UUID) async -> Goal? { saved.last { $0.userId == userId } }
}

private struct LocalGoalRepository: GoalRepository {
    let store: LocalStore
    func saveGoal(_ goal: Goal) async throws { try store.saveGoal(goal) }
    func latestGoal(userId: UUID) async -> Goal? { store.getLatestGoal(userId: userId) }
}
