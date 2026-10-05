import SwiftUI

struct StatusSummaryContent: View {
    let summary: DailySummary
    let goal: Goal?

    private var calorieBalance: CalorieBalance? {
        goal.flatMap { GoalCalculator.calorieBalance(dailyGoal: $0.dailyCalories, consumed: summary.totalCalories) }
    }

    var remainingCalories: Int {
        calorieBalance?.remaining ?? 0
    }

    var overCalories: Int {
        calorieBalance?.over ?? 0
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Kalorier")
                    .font(AppTypography.captionEmphasis)
                    .foregroundColor(AppColors.energyTextSecondary)
                Text("\(NutritionDisplay.wholeCalories(summary.totalCalories)) kcal")
                    .font(AppTypography.heroValue)
                    .foregroundColor(AppColors.deepInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let goal {
                    (
                        Text(overCalories > 0 ? "\(overCalories) kcal over mål" : "\(remainingCalories) kcal igjen")
                            .font(AppTypography.secondaryEmphasis)
                        + Text(overCalories > 0 ? "" : " av \(goal.dailyCalories)")
                            .font(AppTypography.secondary)
                    )
                        .foregroundColor(AppColors.energyTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                nutrient(label: "Proteiner", value: summary.totalProtein, target: goal?.proteinTargetG, tint: AppColors.macroProteinTint)
                nutrient(label: "Karbohydrater", value: summary.totalCarbs, target: goal?.carbsTargetG, tint: AppColors.macroCarbTint)
                nutrient(label: "Fett", value: summary.totalFat, target: goal?.fatTargetG, tint: AppColors.macroFatTint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func nutrient(label: String, value: Float, target: Float?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 6, height: 6).accessibilityHidden(true)
                Text(label)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.energyTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            (
                Text("\(NutritionDisplay.wholeGrams(value))")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.deepInk)
                + Text(target.map { " / \(NutritionDisplay.wholeGrams($0)) g" } ?? " g")
                    .font(target == nil ? AppTypography.bodyEmphasis : AppTypography.body)
                    .foregroundColor(target == nil ? AppColors.deepInk : AppColors.energyTextSecondary)
            )
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(target.map { "\(label), \(NutritionDisplay.wholeGrams(value)) gram spist, mål \(NutritionDisplay.wholeGrams($0)) gram" }
                            ?? "\(label), \(NutritionDisplay.wholeGrams(value)) gram spist")
    }
}
