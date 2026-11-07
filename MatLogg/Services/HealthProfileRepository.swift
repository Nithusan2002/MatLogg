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
    var hasUnassignedLegacyDetails: Bool { get }
    func recoverLegacyDetails(userId: UUID) throws -> PersonalDetails?
}

extension PersonalDetailsStore {
    var hasUnassignedLegacyDetails: Bool { false }
    func recoverLegacyDetails(userId: UUID) throws -> PersonalDetails? { nil }
}

struct UserDefaultsPersonalDetailsStore: PersonalDetailsStore {
    private let legacyKey = "personalDetails"
    private let legacyOwnerKey = "personalDetails.legacyOwnerId"

    var hasUnassignedLegacyDetails: Bool {
        defaults.string(forKey: legacyOwnerKey) == nil && legacyDetails != nil
    }

    private var legacyDetails: PersonalDetails? {
        guard let data = defaults.data(forKey: legacyKey) else { return nil }
        return try? JSONDecoder().decode(PersonalDetails.self, from: data)
    }

    /// Only an explicit recovery action establishes ownership of pre-profile data.
    func recoverLegacyDetails(userId: UUID) throws -> PersonalDetails? {
        guard hasUnassignedLegacyDetails else { return nil }
        defaults.set(userId.uuidString, forKey: legacyOwnerKey)
        return try migrateLegacyDetails(userId: userId)
    }

    private func migrateLegacyDetails(userId: UUID) throws -> PersonalDetails? {
        guard defaults.string(forKey: legacyOwnerKey) == userId.uuidString,
              let legacy = legacyDetails else { return nil }
        let existing = defaults.data(forKey: scopedKey(userId))
        // Preserve undecodable scoped data instead of silently overwriting it.
        let current = try existing.map { try JSONDecoder().decode(PersonalDetails.self, from: $0) } ?? .empty
        let merged = PersonalDetails(displayName: current.displayName ?? legacy.displayName,
            weightKg: current.weightKg ?? legacy.weightKg, heightCm: current.heightCm ?? legacy.heightCm,
            birthDate: current.birthDate ?? legacy.birthDate, gender: current.gender ?? legacy.gender,
            activityLevel: current.activityLevel ?? legacy.activityLevel)
        try save(merged, userId: userId)
        defaults.removeObject(forKey: legacyKey)
        return merged
    }
    var defaults: UserDefaults = .standard

    func load(userId: UUID) -> PersonalDetails {
        if let migrated = try? migrateLegacyDetails(userId: userId) { return migrated }
        guard let data = defaults.data(forKey: scopedKey(userId)),
              let details = try? JSONDecoder().decode(PersonalDetails.self, from: data) else { return .empty }
        return details
    }

    func save(_ details: PersonalDetails, userId: UUID) throws {
        let data = try JSONEncoder().encode(details)
        defaults.set(data, forKey: scopedKey(userId))
    }

    private func scopedKey(_ userId: UUID) -> String {
        "personalDetails.\(userId.uuidString)"
    }
}
