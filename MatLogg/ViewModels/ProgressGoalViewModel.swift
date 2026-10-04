import Combine
import Foundation

@MainActor
final class ProgressGoalViewModel: ObservableObject {
    @Published private(set) var goal: Goal?
    init(health: HealthProfileViewModel) {
        health.$currentGoal.assign(to: &$goal)
    }
}
