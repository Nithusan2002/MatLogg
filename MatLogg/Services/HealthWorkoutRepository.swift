import Foundation
import HealthKit

nonisolated struct HealthWorkoutSummary: Equatable, Identifiable, Sendable {
    let id: UUID
    let startDate: Date
    let title: String
    let duration: TimeInterval
}

nonisolated struct HealthWorkoutSnapshot: HealthReadSnapshot {
    let range: DateInterval
    let workouts: [HealthWorkoutSummary]
    var isExampleData = false
    var hasData: Bool { !workouts.isEmpty }
}

final class HealthWorkoutRepository: HealthReadRepository {
    private let store = HKHealthStore()

    var availability: HealthDataAvailability { HKHealthStore.isHealthDataAvailable() ? .available : .unavailable }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
    }

    func read(in range: DateInterval, through date: Date) async throws -> HealthWorkoutSnapshot {
        let end = min(range.end, date)
        guard range.start < end else { return HealthWorkoutSnapshot(range: range, workouts: []) }
        let dates = HKQuery.predicateForSamples(withStart: range.start, end: end, options: .strictStartDate)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(dates)],
            sortDescriptors: [SortDescriptor(\HKWorkout.startDate, order: .reverse)]
        )
        let samples = try await query.result(for: store)
        let workouts = samples.map {
            HealthWorkoutSummary(id: $0.uuid, startDate: $0.startDate, title: title(for: $0.workoutActivityType), duration: $0.duration)
        }
        return HealthWorkoutSnapshot(range: range, workouts: workouts)
    }

    private func title(for activity: HKWorkoutActivityType) -> String {
        switch activity {
        case .walking: "Gåtur"
        case .hiking: "Fottur"
        case .running: "Løping"
        case .cycling: "Sykling"
        case .traditionalStrengthTraining, .functionalStrengthTraining: "Styrke"
        case .swimming: "Svømming"
        case .yoga: "Yoga"
        case .highIntensityIntervalTraining: "Intervalltrening"
        case .rowing: "Roing"
        case .crossCountrySkiing: "Langrenn"
        case .dance, .socialDance, .cardioDance: "Dans"
        default: "Annen trening"
        }
    }
}

#if DEBUG
/// Explicit UI test fixture. Never reads or writes the device's Health store.
struct QAHealthWorkoutRepository: HealthReadRepository {
    private let ids = [UUID(), UUID(), UUID(), UUID()]
    var availability: HealthDataAvailability { .available }

    func requestAccess() async throws {}

    func read(in range: DateInterval, through date: Date) async throws -> HealthWorkoutSnapshot {
        let previousWeek = Calendar.current.date(byAdding: .day, value: -7, to: date) ?? date
        let workouts = [
            HealthWorkoutSummary(id: ids[0], startDate: date, title: "Styrke", duration: 2700),
            HealthWorkoutSummary(id: ids[1], startDate: date, title: "Gåtur", duration: 1920),
            HealthWorkoutSummary(id: ids[2], startDate: date, title: "Løping", duration: 1200),
            HealthWorkoutSummary(id: ids[3], startDate: previousWeek, title: "Sykling", duration: 3600)
        ]
        return HealthWorkoutSnapshot(
            range: range,
            workouts: workouts.filter { $0.startDate >= range.start && $0.startDate < range.end },
            isExampleData: true
        )
    }
}
#endif
