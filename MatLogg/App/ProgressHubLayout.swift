import Foundation

nonisolated enum ProgressHubArea: String, CaseIterable, Codable, Identifiable, Sendable {
    case nutrition, weight, steps
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nutrition: return "Mat og næring"
        case .weight: return "Vekt"
        case .steps: return "Skritt"
        }
    }
    var symbol: String {
        switch self {
        case .nutrition: return "fork.knife"
        case .weight: return "scalemass"
        case .steps: return "figure.walk"
        }
    }
}

nonisolated struct ProgressHubLayout: Equatable, Sendable {
    var order: [ProgressHubArea]
    var visible: Set<ProgressHubArea>

    static func standard(hasWeightHistory: Bool) -> Self {
        Self(order: [.nutrition, .steps, .weight], visible: hasWeightHistory ? [.nutrition, .weight] : [.nutrition])
    }

    var visibleAreas: [ProgressHubArea] { order.filter { visible.contains($0) } }
}

nonisolated enum ProgressHubStorage {
    static let prefix = "progressHub."
    static func key(_ owner: UUID) -> String { prefix + owner.uuidString }
}
