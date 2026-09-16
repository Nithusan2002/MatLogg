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
        self.personalDetails = personalDetailsStore.load()
    }

    func loadGoal(userId: UUID) async {
        currentGoal = await repository.latestGoal(userId: userId)
    }

    func useDevelopmentGoalIfMissing(userId: UUID, safeModeEnabled: Bool) {
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
            activityLevel: .moderat,
            safeModeEnabled: safeModeEnabled
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
        errorMessage = nil
        do {
            try personalDetailsStore.save(details)
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
        currentGoal = nil
        weightEntries = []
        errorMessage = nil
    }
}
