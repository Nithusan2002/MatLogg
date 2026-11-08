import Foundation
import HealthKit

final class HealthWeightRepository: HealthReadRepository {
    private let store: HKHealthStore
    private let type = HKQuantityType(.bodyMass)
    private let unit = HKUnit.gramUnit(with: .kilo)

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    var availability: HealthDataAvailability { HKHealthStore.isHealthDataAvailable() ? .available : .unavailable }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [], read: [type])
    }

    func read(in range: DateInterval, through date: Date) async throws -> HealthWeightSnapshot {
        let end = min(range.end, date)
        let start = min(range.start, end)
        let points = start < end ? Array(try await measurements(from: start, before: end).reversed()) : []
        let latest: ProgressWeightMeasurement?
        if let last = points.last {
            latest = last
        } else {
            try Task.checkCancellation()
            latest = try await measurements(from: nil, before: start, limit: 1).first
        }
        return HealthWeightSnapshot(
            range: range,
            overview: ProgressWeightOverview(latest: latest, points: points, source: .appleHealth)
        )
    }

    private func measurements(from start: Date?, before end: Date, limit: Int? = nil) async throws -> [ProgressWeightMeasurement] {
        let dates = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let positive = HKQuery.predicateForQuantitySamples(with: .greaterThan, quantity: HKQuantity(unit: unit, doubleValue: 0))
        let finite = HKQuery.predicateForQuantitySamples(
            with: .lessThanOrEqualTo, quantity: HKQuantity(unit: .gram(), doubleValue: Double.greatestFiniteMagnitude)
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dates, positive, finite])
        let query = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\HKQuantitySample.startDate, order: .reverse)],
            limit: limit
        )
        let samples = try await query.result(for: store)
        return samples.compactMap { sample in
            let kg = sample.quantity.doubleValue(for: unit)
            guard kg.isFinite, kg > 0 else { return nil }
            return ProgressWeightMeasurement(id: sample.uuid, date: sample.startDate, weightKg: kg)
        }
    }
}

#if DEBUG
/// Explicit UI test fixture. Never reads or writes the device's Health store.
struct QAHealthWeightRepository: HealthReadRepository {
    private let id = UUID()
    var availability: HealthDataAvailability { .available }
    func requestAccess() async throws {}

    func read(in range: DateInterval, through date: Date) async throws -> HealthWeightSnapshot {
        let current = ProgressWeightMeasurement(id: id, date: date.addingTimeInterval(-1), weightKg: 71.2)
        let latest = current.date < range.end ? current : nil
        let points = latest.map { $0.date >= range.start ? [$0] : [] } ?? []
        return HealthWeightSnapshot(
            range: range,
            overview: ProgressWeightOverview(latest: latest, points: points, source: .appleHealth),
            isExampleData: true
        )
    }
}
#endif
