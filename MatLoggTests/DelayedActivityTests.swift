import Foundation
import Testing
@testable import MatLogg

@MainActor
struct DelayedActivityTests {
    @Test func quickOperationDoesNotPublishVisibleActivity() async {
        let activity = DelayedActivity()
        var values: [Bool] = []
        activity.update(isActive: true) { values.append($0) }
        activity.update(isActive: false) { values.append($0) }
        try? await Task.sleep(for: .milliseconds(240))
        #expect(!values.contains(true))
    }

    @Test func slowOperationShowsFeedbackAndClearsOnCompletion() async {
        let activity = DelayedActivity()
        var visible = false
        activity.update(isActive: true) { visible = $0 }
        #expect(!visible)
        try? await Task.sleep(for: .milliseconds(240))
        #expect(visible)
        activity.update(isActive: false) { visible = $0 }
        #expect(!visible)
    }

    @Test func replacedOperationCannotPublishOldFeedback() async {
        let activity = DelayedActivity()
        var oldVisible = false
        var newVisible = false
        activity.update(isActive: true) { oldVisible = $0 }
        activity.update(isActive: true) { newVisible = $0 }
        try? await Task.sleep(for: .milliseconds(240))
        #expect(!oldVisible)
        #expect(newVisible)
        activity.update(isActive: false) { newVisible = $0 }
    }
}
