import Foundation

nonisolated struct ProgressWeekOverview {
    struct Day: Identifiable {
        let date: Date
        let calories: Double?
        let steps: Double?
        let workouts: [HealthWorkoutSummary]

        var id: Date { date }
    }

    let days: [Day]
    let totalCalories: Int?
    let averageCalories: Int?
    let loggedDays: Int
    let totalSteps: Int?
    let averageSteps: Int?
    let workoutCount: Int

    init(range: ProgressDateRange, nutrition: ProgressNutritionOverview, steps: StepCountSnapshot?,
         workouts: HealthWorkoutSnapshot?, calendar: Calendar) {
        let foodByDay = Dictionary(grouping: nutrition.recordedDays) { calendar.startOfDay(for: $0.date) }
        let stepBuckets = steps?.range == range.interval ? steps?.buckets ?? [] : []
        let stepsByDay = Dictionary(grouping: stepBuckets) { calendar.startOfDay(for: $0.date) }
        let sessions = workouts?.range == range.interval ? workouts?.workouts ?? [] : []
        let workoutsByDay = Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startDate) }
        days = range.dates.map { date in
            Day(date: date,
                calories: foodByDay[date].map { Double($0.reduce(Float.zero) { $0 + $1.totalCalories }) },
                steps: stepsByDay[date].map { $0.reduce(0) { $0 + $1.steps } },
                workouts: workoutsByDay[date] ?? [])
        }
        let calories = days.compactMap(\.calories)
        let stepValues = days.compactMap(\.steps)
        loggedDays = calories.count
        let calorieSum = calories.reduce(0, +)
        totalCalories = calories.isEmpty ? nil : Int(exactly: calorieSum.rounded())
        averageCalories = calories.isEmpty ? nil : Int(exactly: (calorieSum / Double(calories.count)).rounded())
        let stepSum = stepValues.reduce(0, +)
        totalSteps = stepValues.isEmpty ? nil : Int(exactly: stepSum.rounded(.towardZero))
        averageSteps = stepValues.isEmpty ? nil : Int(exactly: (stepSum / Double(stepValues.count)).rounded())
        workoutCount = days.reduce(0) { $0 + $1.workouts.count }
    }
}
