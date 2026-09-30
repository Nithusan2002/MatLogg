import Foundation
import Combine

@MainActor
final class HealthProfileViewModel: ObservableObject {
    @Published private(set) var currentGoal: Goal?
    @Published private(set) var personalDetails: PersonalDetails
    @Published private(set) var weightEntries: [WeightEntry] = []
    @Published private(set) var errorMessage: String?

    private let repository: any HealthProfileRepository
    private let personalDetailsStore: any PersonalDetailsStore
    private var activeUserId: UUID?

    convenience init(repository: any HealthProfileRepository) {
        self.init(
            repository: repository,
            personalDetailsStore: UserDefaultsPersonalDetailsStore()
        )
    }

    init(
        repository: any HealthProfileRepository,
        personalDetailsStore: any PersonalDetailsStore
    ) {
        self.repository = repository
        self.personalDetailsStore = personalDetailsStore
        self.personalDetails = .empty
    }

    func acceptSavedPersonalDetails(_ details: PersonalDetails) {
        personalDetails = details
    }

    func acceptSavedGoal(_ goal: Goal) {
        currentGoal = goal
    }

    func acceptOnboardingCompletion(goal: Goal?, personalDetails: PersonalDetails?) {
        if let goal {
            currentGoal = goal
        }
        if let personalDetails {
            self.personalDetails = personalDetails
        }
    }

    func loadGoal(userId: UUID) async {
        activeUserId = userId
        personalDetails = personalDetailsStore.load(userId: userId)
        currentGoal = await repository.latestGoal(userId: userId)
    }

    func useDevelopmentGoalIfMissing(userId: UUID) {
        guard currentGoal == nil else { return }
        currentGoal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 150,
            carbsTargetG: 250,
            fatTargetG: 65,
            intent: .maintain,
            pace: .calm,
            activityLevel: .moderat
        )
    }

    @discardableResult
    func saveGoal(_ goal: Goal) async -> Bool {
        errorMessage = nil
        do {
            try await repository.saveGoal(goal)
            currentGoal = goal
            return true
        } catch {
            errorMessage = "Kunne ikke lagre mål: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func savePersonalDetails(_ details: PersonalDetails) -> Bool {
        guard let activeUserId else {
            errorMessage = "Kunne ikke lagre personlige detaljer uten en aktiv profil."
            return false
        }
        errorMessage = nil
        do {
            try personalDetailsStore.save(details, userId: activeUserId)
            personalDetails = details
            return true
        } catch {
            errorMessage = "Kunne ikke lagre personlige detaljer: \(error.localizedDescription)"
            return false
        }
    }

    func loadWeightEntries(userId: UUID) async {
        weightEntries = await repository.getWeightEntries(userId: userId)
    }

    @discardableResult
    func saveWeight(date: Date, weightKg: Double, userId: UUID) async -> Bool {
        guard weightKg > 0 else { return false }
        errorMessage = nil
        do {
            try await repository.saveWeightEntry(WeightEntry(userId: userId, date: date, weightKg: weightKg))
            await loadWeightEntries(userId: userId)
            return true
        } catch {
            errorMessage = "Kunne ikke lagre vekt: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func deleteWeight(_ entry: WeightEntry, userId: UUID) async -> Bool {
        guard entry.userId == userId else {
            errorMessage = "Kunne ikke slette vekt: Registreringen tilhører en annen bruker"
            return false
        }
        errorMessage = nil
        do {
            try await repository.deleteWeightEntry(entry.id)
            await loadWeightEntries(userId: userId)
            return true
        } catch {
            errorMessage = "Kunne ikke slette vekt: \(error.localizedDescription)"
            return false
        }
    }

    func resetUserState() {
        activeUserId = nil
        currentGoal = nil
        personalDetails = .empty
        weightEntries = []
        errorMessage = nil
    }
}
