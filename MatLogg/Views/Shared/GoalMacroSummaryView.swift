import SwiftUI

/// Shared presentation for the first suggestion and later recalculations.
struct GoalMacroSummaryView: View {
    let macros: MacroTargets

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            macro("Protein", value: macros.proteinG)
            macro("Karbohydrater", value: macros.carbsG)
            macro("Fett", value: macros.fatG)
        }
        .font(AppTypography.body)
    }

    private func macro(_ title: String, value: Float) -> some View {
        Text("\(title): \(value.formatted(.number.precision(.fractionLength(0...1)))) g/dag")
    }
}
