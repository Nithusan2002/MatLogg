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
    var defaults: UserDefaults = .standard

    func load(userId: UUID) -> PersonalDetails {
        let key = scopedKey(userId)
        if let data = defaults.data(forKey: key),
           let details = try? JSONDecoder().decode(PersonalDetails.self, from: data) {
            return details
        }
        guard let legacyData = defaults.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(PersonalDetails.self, from: legacyData) else { return .empty }
        defaults.set(legacyData, forKey: key)
        defaults.removeObject(forKey: legacyKey)
        return legacy
    }

    func save(_ details: PersonalDetails, userId: UUID) throws {
        let data = try JSONEncoder().encode(details)
        defaults.set(data, forKey: scopedKey(userId))
    }

    private func scopedKey(_ userId: UUID) -> String {
        "personalDetails.\(userId.uuidString)"
    }
}
