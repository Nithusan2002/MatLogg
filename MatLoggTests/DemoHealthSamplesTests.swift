import Foundation
import Testing
@testable import MatLogg

struct DemoHealthSamplesTests {
    @Test func examplesRespectRangeAndCutoffAndRemainMarked() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = try #require(calendar.date(byAdding: .day, value: -7, to: today))
        let end = try #require(calendar.date(byAdding: .day, value: 7, to: today))
        let range = DateInterval(start: start, end: end)
        let steps = DemoHealthSamples.steps(in: range, through: today)
        #expect(steps.isExampleData && steps.hasData)
        #expect(steps.buckets.count == 7)
        #expect(steps.buckets.allSatisfy { $0.date >= start && $0.date < today && $0.steps >= 0 })
        let weight = DemoHealthSamples.weight(in: range, through: today)
        #expect(weight.isExampleData && weight.hasData)
        #expect(weight.overview.points.count == 7)
        #expect(weight.overview.points.allSatisfy { $0.date >= start && $0.date < today && $0.weightKg > 0 })
        let workouts = DemoHealthSamples.workouts(in: range, through: today)
        #expect(workouts.isExampleData && workouts.hasData)
        #expect(workouts.workouts.count == 3)
        #expect(workouts.workouts.allSatisfy { $0.startDate >= start && $0.startDate < today && $0.duration > 0 })
        let future = DateInterval(start: today, end: end)
        #expect(!DemoHealthSamples.steps(in: future, through: today).hasData)
        #expect(!DemoHealthSamples.weight(in: future, through: today).hasData)
        #expect(!DemoHealthSamples.workouts(in: future, through: today).hasData)
    }

    @Test @MainActor func demoLoadsWithoutEnablingHealthAndClearsOnHide() async throws {
        let suite = "demo-health-test-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let connections = UserDefaultsHealthConnectionRepository(defaults: defaults, kind: .steps)
        let owner = UUID()
        let today = Calendar.current.startOfDay(for: Date())
        let range = DateInterval(start: today.addingTimeInterval(-7 * 86400), end: today)
        let repository = DemoHealthReadRepository<StepCountSnapshot>(makeExample: DemoHealthSamples.steps)
        let model = StepCountViewModel(repository: repository, connections: connections)
        await model.update(owner: owner, isVisible: true, range: range)
        #expect(model.availability == .demo)
        #expect(model.snapshot(for: range)?.isExampleData == true)
        #expect(!model.isEnabled)
        await model.connect()
        #expect(!connections.isEnabled(owner: owner))
        #expect(defaults.object(forKey: HealthReadKind.steps.preferenceKey(owner: owner)) == nil)
        model.suspend()
        #expect(model.snapshot(for: range) == nil)
        await model.update(owner: nil, isVisible: true, range: range)
        #expect(model.snapshot(for: range) == nil)
    }
}
