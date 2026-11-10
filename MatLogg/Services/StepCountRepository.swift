import Foundation
import HealthKit

final class HealthKitStepCountRepository: HealthReadRepository {
    private let store: HKHealthStore
    private let calendar: Calendar
    private let type = HKQuantityType(.stepCount)

    init(store: HKHealthStore = HKHealthStore(), calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    var availability: HealthDataAvailability { HKHealthStore.isHealthDataAvailable() ? .available : .unavailable }

    func requestAccess() async throws {
        // Completion means the request was handled, not that read access was granted.
        try await store.requestAuthorization(toShare: [], read: [type])
    }

    func read(in range: DateInterval, through date: Date) async throws -> StepCountSnapshot {
        let end = min(range.end, date)
        let granularity = StepCountGranularity(range: range, calendar: calendar)
        guard range.start < end else {
            return StepCountSnapshot(range: range, buckets: [], updatedAt: date, granularity: granularity)
        }
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: end, options: .strictStartDate)
        var interval = DateComponents(calendar: calendar, timeZone: calendar.timeZone)
        interval.setValue(1, for: granularity.component)
        let query = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: range.start,
            intervalComponents: interval
        )
        let collection = try await query.result(for: store)
        let buckets: [StepCountBucket] = try collection.statistics().compactMap { statistics in
            guard statistics.startDate >= range.start, statistics.startDate < end,
                  let quantity = statistics.sumQuantity() else { return nil }
            let value = quantity.doubleValue(for: .count())
            guard value.isFinite, value >= 0, value < Double(Int.max) else { throw StepCountError.invalidValue }
            return StepCountBucket(date: statistics.startDate, steps: value)
        }
        return StepCountSnapshot(range: range, buckets: buckets.sorted { $0.date < $1.date },
                                 updatedAt: date, granularity: granularity)
    }
}

private enum StepCountError: Error { case invalidValue }

#if DEBUG
/// Explicit UI-test fixture. Never reads or writes the device's Health store.
struct QAStepCountRepository: HealthReadRepository {
    var count: Int? = 6543
    var availability: HealthDataAvailability { .available }
    func requestAccess() async throws {}
    func read(in range: DateInterval, through date: Date) async throws -> StepCountSnapshot {
        let calendar = Calendar.current
        let granularity = StepCountGranularity(range: range, calendar: calendar)
        let end = min(range.end, date)
        let dates = (0..<4).compactMap { offset in
            calendar.date(byAdding: granularity.component, value: offset, to: range.start)
        }.filter { $0 < end }
        var buckets: [StepCountBucket] = []
        if let count, let lastDate = dates.last {
            let portions = [count / 8, count / 3, count / 5]
            buckets = zip(dates.dropLast(), portions).map { StepCountBucket(date: $0, steps: Double($1)) }
            let remainder = Double(count) - buckets.reduce(0) { $0 + $1.steps }
            buckets.append(StepCountBucket(date: lastDate, steps: remainder))
        }
        return StepCountSnapshot(range: range, buckets: buckets, updatedAt: date,
                                 granularity: granularity, isExampleData: true)
    }
}
#endif
