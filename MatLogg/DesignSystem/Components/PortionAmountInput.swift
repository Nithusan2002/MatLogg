import SwiftUI

struct PortionAmountInput: View {
    @ObservedObject var model: AmountSelectionViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button(model.unit.spokenName) { model.select(nil) }
                ForEach(model.servings) { serving in
                    Button(serving.label) { model.select(serving) }
                }
                if let selected = model.selectedServing, !model.servings.contains(where: { $0.id == selected.id }) {
                    Button("\(selected.portionLabel) (lagret grunnlag)") { model.select(selected) }
                }
            } label: {
                HStack {
                    Text("Mengde")
                    Spacer()
                    Text(model.selectedServing?.portionLabel ?? model.unit.spokenName)
                    Image(systemName: "chevron.down")
                }
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.ink)
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Velg mengdeenhet")
            .accessibilityIdentifier("portion-unit-picker")

            if dynamicTypeSize.isAccessibilitySize {
                amountField
                if model.selectedServing != nil {
                    HStack {
                        decreaseButton
                        Spacer()
                        increaseButton
                    }
                }
            } else {
                HStack {
                    if model.selectedServing != nil { decreaseButton }
                    amountField
                    if model.selectedServing != nil { increaseButton }
                }
            }
            if let serving = model.selectedServing {
                Text("\(PortionDisplay.number(serving.grams)) \(model.unit.rawValue) per \(serving.portionLabel)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text(sourceLabel(serving.source))
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                if let amount = model.amount {
                    Text("Totalt: \(PortionDisplay.number(amount)) \(model.unit.rawValue)")
                        .font(AppTypography.body)
                        .accessibilityIdentifier("portion-total")
                }
            }
            if !model.isValid {
                Text("Skriv en gyldig mengde. Totalen må være større enn 0 og høyst 10 000 \(model.unit.rawValue).")
                    .font(AppTypography.caption).foregroundStyle(AppColors.action)
            }
        }
    }

    private func sourceLabel(_ source: ServingSource) -> String {
        switch source {
        case .openFoodFacts: return "Porsjonsgrunnlag fra Open Food Facts"
        case .user: return "Egen porsjon"
        case .heuristic: return "Beregnet porsjonsgrunnlag"
        }
    }

    private var amountField: some View {
        AmountInputRow(title: model.selectedServing == nil ? "Mengde" : "Antall",
                       gramsText: $model.text, unit: model.selectedServing == nil ? model.unit.rawValue : "")
    }

    private var decreaseButton: some View {
        stepButton("minus", label: "Reduser antall", delta: -1).disabled(!model.canDecrease)
    }

    private var increaseButton: some View {
        stepButton("plus", label: "Øk antall", delta: 1).disabled(!model.canIncrease)
    }

    private func stepButton(_ icon: String, label: String, delta: Double) -> some View {
        Button { model.step(delta) } label: {
            Image(systemName: icon).frame(width: 44, height: 44)
        }
        .foregroundStyle(AppColors.action)
        .accessibilityLabel(label)
        .accessibilityIdentifier(delta > 0 ? "portion-increase" : "portion-decrease")
    }
}
