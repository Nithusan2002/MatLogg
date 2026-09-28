import Foundation

protocol GoalRepository {
    func saveGoal(_ goal: Goal) async throws
    func latestGoal(userId: UUID) async -> Goal?
}

protocol HealthProfileRepository: GoalRepository {
    func saveWeightEntry(_ entry: WeightEntry) async throws
    func deleteWeightEntry(_ id: UUID) async throws
    func getWeightEntries(userId: UUID) async -> [WeightEntry]
}

extension DatabaseService: HealthProfileRepository {}

protocol PersonalDetailsStore {
    func load(userId: UUID) -> PersonalDetails
    func save(_ details: PersonalDetails, userId: UUID) throws
}

struct UserDefaultsPersonalDetailsStore: PersonalDetailsStore {
    private let legacyKey = "personalDetails"

    func load(userId: UUID) -> PersonalDetails {
        let key = scopedKey(userId)
        if let data = UserDefaults.standard.data(forKey: key),
           let details = try? JSONDecoder().decode(PersonalDetails.self, from: data) {
            return details
        }
        guard let legacyData = UserDefaults.standard.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(PersonalDetails.self, from: legacyData) else { return .empty }
        UserDefaults.standard.set(legacyData, forKey: key)
        UserDefaults.standard.removeObject(forKey: legacyKey)
        return legacy
    }

    func save(_ details: PersonalDetails, userId: UUID) throws {
        let data = try JSONEncoder().encode(details)
        UserDefaults.standard.set(data, forKey: scopedKey(userId))
    }

    private func scopedKey(_ userId: UUID) -> String {
        "personalDetails.\(userId.uuidString)"
    }
}
