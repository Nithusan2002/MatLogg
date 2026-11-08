import Foundation

nonisolated enum ProgressHubArea: String, CaseIterable, Codable, Identifiable, Sendable {
    case nutrition, weight, steps, workouts
    var id: String { rawValue }
    var isCompact: Bool { self == .steps || self == .weight }
    var title: String {
        switch self {
        case .nutrition: return "Mat og næring"
        case .weight: return "Vekt"
        case .steps: return "Skritt"
        case .workouts: return "Treningsøkter"
        }
    }
    var symbol: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .weight: return "scalemass"
        case .steps: return "figure.walk"
        case .workouts: return "dumbbell"
        }
    }
}

nonisolated struct ProgressHubLayout: Equatable, Sendable {
    var order: [ProgressHubArea]
    var visible: Set<ProgressHubArea>

    static func standard(hasWeightHistory: Bool) -> Self {
        Self(order: [.nutrition, .steps, .weight, .workouts], visible: hasWeightHistory ? [.nutrition, .weight] : [.nutrition])
    }

    var visibleAreas: [ProgressHubArea] { order.filter { visible.contains($0) } }
}

nonisolated enum ProgressHubStorage {
    static let prefix = "progressHub."
    static func key(_ owner: UUID) -> String { prefix + owner.uuidString }
}
