import Foundation

nonisolated enum HealthDataAvailability: Equatable, Sendable {
    case available, unavailable, demo
}

nonisolated enum HealthReadKind: CaseIterable {
    case steps, weight

    var preferencePrefix: String {
        switch self {
        case .steps: "healthStepsEnabled."
        case .weight: "healthWeightEnabled."
        }
    }

    func preferenceKey(owner: UUID) -> String { preferencePrefix + owner.uuidString }
}

nonisolated protocol HealthReadSnapshot: Equatable, Sendable {
    var range: DateInterval { get }
    var hasData: Bool { get }
    var isExampleData: Bool { get }
}
