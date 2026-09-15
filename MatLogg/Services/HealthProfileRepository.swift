import Foundation

protocol HealthProfileRepository {
    func saveGoal(_ goal: Goal) async throws
    func latestGoal(userId: UUID) async -> Goal?
    func saveWeightEntry(_ entry: WeightEntry) async throws
    func deleteWeightEntry(_ id: UUID) async throws
    func getWeightEntries(userId: UUID) async -> [WeightEntry]
}

extension DatabaseService: HealthProfileRepository {}

protocol PersonalDetailsStore {
    func load() -> PersonalDetails
    func save(_ details: PersonalDetails) throws
}

struct UserDefaultsPersonalDetailsStore: PersonalDetailsStore {
    private let key = "personalDetails"

    func load() -> PersonalDetails {
        guard let data = UserDefaults.standard.data(forKey: key),
              let details = try? JSONDecoder().decode(PersonalDetails.self, from: data) else {
            return .empty
        }
        return details
    }

    func save(_ details: PersonalDetails) throws {
        let data = try JSONEncoder().encode(details)
        UserDefaults.standard.set(data, forKey: key)
    }
}
