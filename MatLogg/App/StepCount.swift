import Foundation

nonisolated enum StepCountGranularity: Equatable, Sendable {
    case hour, day

    init(range: DateInterval, calendar: Calendar) {
        self = calendar.dateInterval(of: .day, for: range.start) == range ? .hour : .day
    }

    var component: Calendar.Component { self == .hour ? .hour : .day }
}

nonisolated struct StepCountBucket: Equatable, Identifiable, Sendable {
    let date: Date
    let steps: Double
    var id: Date { date }
}

nonisolated struct StepCountSnapshot: HealthReadSnapshot {
    let range: DateInterval
    let buckets: [StepCountBucket]
    let updatedAt: Date
    var granularity: StepCountGranularity = .day
    var isExampleData = false

    var hasData: Bool { count != nil }

    var count: Int? {
        guard !buckets.isEmpty else { return nil }
        let total = buckets.reduce(0) { $0 + $1.steps }
        return Int(exactly: total.rounded(.towardZero))
    }

    func trendRuns(calendar: Calendar = .current) -> [[StepCountBucket]] {
        var runs: [[StepCountBucket]] = []
        var nextDate: Date?
        for bucket in buckets {
            if bucket.date == nextDate, let last = runs.indices.last {
                runs[last].append(bucket)
            } else {
                runs.append([bucket])
            }
            nextDate = calendar.date(byAdding: granularity.component, value: 1, to: bucket.date)
        }
        return runs
    }
}
