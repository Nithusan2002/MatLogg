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
    static let standardOrder: [ProgressHubArea] = [.nutrition, .steps, .weight, .workouts]

    var visible: Set<ProgressHubArea>

    static func standard(hasWeightHistory: Bool) -> Self {
        Self(visible: hasWeightHistory ? [.nutrition, .weight] : [.nutrition])
    }

    var visibleAreas: [ProgressHubArea] { Self.standardOrder.filter { visible.contains($0) } }

    func cardGroups(for period: ProgressPeriod) -> [[ProgressHubArea]] {
        if period == .week {
            let weekAreas = visibleAreas.filter { $0 != .weight }
            return (weekAreas.isEmpty ? [] : [weekAreas]) + (visible.contains(.weight) ? [[.weight]] : [])
        }

        var groups: [[ProgressHubArea]] = []
        for area in visibleAreas {
            if area.isCompact, let last = groups.last, last.count == 1, last.first?.isCompact == true {
                groups[groups.count - 1].append(area)
            } else {
                groups.append([area])
            }
        }
        return groups
    }
}

nonisolated enum ProgressHubStorage {
    static let prefix = "progressHub."
    static func key(_ owner: UUID) -> String { prefix + owner.uuidString }
}
