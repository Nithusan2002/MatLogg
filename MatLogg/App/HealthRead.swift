import Foundation

nonisolated enum HealthDataAvailability: Equatable, Sendable {
    case available, unavailable, demo
}

nonisolated enum HealthReadKind: String, CaseIterable {
    case steps, weight, workouts

    var preferencePrefix: String {
        switch self {
        case .steps: "healthStepsEnabled."
        case .weight: "healthWeightEnabled."
        case .workouts: "healthWorkoutsEnabled."
        }
    }

    func preferenceKey(owner: UUID) -> String { preferencePrefix + owner.uuidString }
}

nonisolated protocol HealthReadSnapshot: Equatable, Sendable {
    var range: DateInterval { get }
    var hasData: Bool { get }
    var isExampleData: Bool { get }
}
