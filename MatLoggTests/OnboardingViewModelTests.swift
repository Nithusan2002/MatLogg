import Foundation
import Testing
@testable import MatLogg

@MainActor
struct OnboardingViewModelTests {
    @Test func quickStartFinishesWithoutSavingGoalOrPersonalDetails() async {
        let repository = OnboardingGoalRepositoryStub()
        let detailsStore = OnboardingPersonalDetailsStoreStub()
        let userId = UUID()
        let viewModel = OnboardingViewModel(
            goalRepository: repository,
            personalDetailsStore: detailsStore
        )

        viewModel.begin(userId: userId, goal: nil, details: .empty)
        viewModel.chooseQuickStart()
        #expect(viewModel.step == .privacy)
        viewModel.advance()
        #expect(viewModel.step == .summary)

        let completion = await viewModel.complete(userId: userId)

        #expect(completion != nil)
        #expect(completion?.goal == nil)
        #expect(completion?.personalDetails == nil)
        #expect(repository.saved.isEmpty)
        #expect(detailsStore.saved.isEmpty)
    }

    @Test func loggingOnlyDoesNotCreateGoal() async {
        let repository = OnboardingGoalRepositoryStub()
        let detailsStore = OnboardingPersonalDetailsStoreStub()
        let userId = UUID()
        let viewModel = OnboardingViewModel(
            goalRepository: repository,
            personalDetailsStore: detailsStore
        )

        viewModel.begin(userId: userId, goal: nil, details: .empty)
        viewModel.advance()
        viewModel.intent = .loggingOnly
        viewModel.advance()
        #expect(viewModel.step == .privacy)
        #expect(!viewModel.shouldCreateGoal)
        viewModel.advance()

        let completion = await viewModel.complete(userId: userId)

        #expect(completion?.goal == nil)
        #expect(repository.saved.isEmpty)
        #expect(detailsStore.saved.isEmpty)
    }

    @Test func completeGoalFlowSavesExplicitGoalAndDetails() async throws {
        let repository = OnboardingGoalRepositoryStub()
        let detailsStore = OnboardingPersonalDetailsStoreStub()
        let userId = UUID()
        let viewModel = OnboardingViewModel(
            goalRepository: repository,
            personalDetailsStore: detailsStore
        )

        viewModel.begin(userId: userId, goal: nil, details: .empty)
        viewModel.advance()
        viewModel.intent = .lose
        viewModel.advance()
        viewModel.pace = .calm
        viewModel.advance()
        viewModel.weightText = "72"
        viewModel.heightText = "178"
        viewModel.ageText = "31"
        viewModel.gender = .mann
        viewModel.activity = .moderat
        viewModel.advance()
        let suggestion = try #require(viewModel.suggestion)
        #expect(viewModel.calorieTarget == suggestion)
        viewModel.advance()
        viewModel.advance()
        viewModel.advance()
        #expect(viewModel.step == .summary)

        let completion = try #require(await viewModel.complete(userId: userId))

        #expect(completion.goal?.userId == userId)
        #expect(completion.goal?.intent == .lose)
        #expect(completion.goal?.dailyCalories == suggestion)
        #expect(repository.saved.count == 1)
        #expect(detailsStore.saved[userId]?.weightKg == 72)
        #expect(detailsStore.saved[userId]?.heightCm == 178)
        #expect(detailsStore.saved[userId]?.activityLevel == .moderat)
    }

    @Test func missingInputsDoNotProduceAHealthEstimate() {
        let viewModel = OnboardingViewModel(
            goalRepository: OnboardingGoalRepositoryStub(),
            personalDetailsStore: OnboardingPersonalDetailsStoreStub()
        )
        viewModel.begin(userId: UUID(), goal: nil, details: .empty)
        viewModel.intent = .lose

        #expect(viewModel.suggestion == nil)
        #expect(!viewModel.hasValidCalorieTarget)
    }

    @Test func saveFailureKeepsDraftAndDoesNotComplete() async {
        let repository = OnboardingGoalRepositoryStub()
        repository.shouldFail = true
        let detailsStore = OnboardingPersonalDetailsStoreStub()
        let userId = UUID()
        let viewModel = OnboardingViewModel(
            goalRepository: repository,
            personalDetailsStore: detailsStore
        )
        viewModel.begin(userId: userId, goal: nil, details: .empty)
        viewModel.calorieTargetText = "2100"
        viewModel.proteinText = "120"
        viewModel.carbsText = "220"
        viewModel.fatText = "70"

        let completion = await viewModel.complete(userId: userId)

        #expect(completion == nil)
        #expect(viewModel.calorieTargetText == "2100")
        #expect(viewModel.errorMessage != nil)
        #expect(repository.saved.isEmpty)
    }
}

@MainActor
private final class OnboardingGoalRepositoryStub: GoalRepository {
    var saved: [Goal] = []
    var shouldFail = false

    func saveGoal(_ goal: Goal) async throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        saved.append(goal)
    }

    func latestGoal(userId: UUID) async -> Goal? {
        saved.last { $0.userId == userId }
    }
}

@MainActor
private final class OnboardingPersonalDetailsStoreStub: PersonalDetailsStore {
    var saved: [UUID: PersonalDetails] = [:]

    func load(userId: UUID) -> PersonalDetails {
        saved[userId] ?? .empty
    }

    func save(_ details: PersonalDetails, userId: UUID) throws {
        saved[userId] = details
    }
}
