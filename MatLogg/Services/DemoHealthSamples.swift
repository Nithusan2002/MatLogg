import Foundation

/// Synthetic presentation values only. No HealthKit access, persistence or upload.
nonisolated enum DemoHealthSamples {
    private static func dates(in range: DateInterval, through date: Date) -> [Date] {
        let calendar = Calendar.current
        var result: [Date] = []
        var day = calendar.startOfDay(for: range.start)
        let end = min(range.end, date)
        while day < end {
            if day >= range.start { result.append(day) }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day), next > day else { break }
            day = next
        }
        return result
    }

    static func steps(in range: DateInterval, through date: Date) -> StepCountSnapshot {
        let calendar = Calendar.current
        let granularity = StepCountGranularity(range: range, calendar: calendar)
        let end = min(range.end, date)
        var cursor = range.start
        var buckets: [StepCountBucket] = []
        while cursor < end {
            let weekday = calendar.component(.weekday, from: cursor)
            let value: Double
            if granularity == .hour {
                let hour = calendar.component(.hour, from: cursor)
                value = hour < 7 || hour > 22 ? 0 : [180, 420, 760, 310, 550][hour % 5]
            } else {
                value = [6400, 8200, 7100, 9400, 7800, 10500, 8900][weekday - 1]
            }
            buckets.append(StepCountBucket(date: cursor, steps: value))
            guard let next = calendar.date(byAdding: granularity.component, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return StepCountSnapshot(range: range, buckets: buckets, updatedAt: date,
                                 granularity: granularity, isExampleData: true)
    }

    static func weight(in range: DateInterval, through date: Date) -> HealthWeightSnapshot {
        let points = dates(in: range, through: date).map { day in
            let weekday = Calendar.current.component(.weekday, from: day)
            return ProgressWeightMeasurement(id: UUID(), date: day,
                                             weightKg: [74.1, 74.0, 74.2, 74.0, 73.9, 74.1, 74.0][weekday - 1])
        }
        return HealthWeightSnapshot(range: range,
            overview: ProgressWeightOverview(latest: points.last, points: points, source: .appleHealth),
            isExampleData: true)
    }

    static func workouts(in range: DateInterval, through date: Date) -> HealthWorkoutSnapshot {
        let calendar = Calendar.current
        let days = dates(in: range, through: date)
        let workouts = days.compactMap { day -> HealthWorkoutSummary? in
            let weekday = calendar.component(.weekday, from: day)
            guard days.count == 1 || [2, 4, 7].contains(weekday),
                  let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day),
                  start < min(range.end, date) else { return nil }
            let strength = weekday == 2
            return HealthWorkoutSummary(id: UUID(), startDate: start, title: strength ? "Styrke" : "Gåtur",
                                        duration: strength ? 2700 : 2100,
                                        symbol: strength ? "dumbbell" : "figure.walk")
        }
        return HealthWorkoutSnapshot(range: range, workouts: workouts.reversed(), isExampleData: true)
    }
}
