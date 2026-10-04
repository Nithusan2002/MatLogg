import SwiftUI

struct PortionAmountInput: View {
    @ObservedObject var model: AmountSelectionViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsServingSource = false
    @ScaledMetric(relativeTo: .body) private var amountControlWidth: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                Button(model.unit.spokenName) { model.select(nil) }
                ForEach(model.servings) { serving in
                    Button(displayLabel(serving.label)) { model.select(serving) }
                }
                if let selected = model.selectedServing, !model.servings.contains(where: { $0.id == selected.id }) {
                    Button("\(displayLabel(selected.portionLabel)) (lagret grunnlag)") { model.select(selected) }
                }
            } label: {
                HStack {
                    Text("Enhet")
                    Spacer()
                    HStack(spacing: 8) {
                        Text(displayLabel(model.selectedServing?.portionLabel ?? model.unit.spokenName))
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .frame(width: amountControlWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
                    .background(AppColors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.controlBorder, lineWidth: 1)
                    }
                }
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.ink)
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Velg mengdeenhet")
            .accessibilityIdentifier("portion-unit-picker")

            if model.selectedServing != nil {
                if dynamicTypeSize.isAccessibilitySize {
                    countLabel
                    countControls
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    HStack(spacing: 8) {
                        countLabel
                        Spacer(minLength: 8)
                        countControls
                    }
                }
                HStack {
                    decreaseButton
                    Spacer(minLength: 0)
                    increaseButton
                }
                .frame(width: amountControlWidth)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                amountField
            }
            if model.selectedServing != nil, let summary = model.amountSummary {
                HStack {
                    Text(summary)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Valgt mengde: \(summary)")
                        .accessibilityIdentifier("portion-total")
                    Spacer(minLength: 8)
                    Button { showsServingSource = true } label: {
                        Image(systemName: "info.circle")
                            .font(AppTypography.body)
                            .frame(width: 44, height: 44)
                    }
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityLabel("Vis kilde for porsjonsstørrelsen")
                    .accessibilityIdentifier("portion-source-info")
                }
            }
            if !model.isValid {
                Text("Skriv en gyldig mengde. Totalen må være større enn 0 og høyst 10 000 \(model.unit.rawValue).")
                    .font(AppTypography.caption).foregroundStyle(AppColors.action)
            }
        }
        .alert("Porsjonsgrunnlag", isPresented: $showsServingSource) {
            Button("OK", role: .cancel) { }
        } message: {
            if let serving = model.selectedServing {
                Text("\(PortionDisplay.number(serving.grams)) \(model.unit.rawValue) per \(displayLabel(serving.portionLabel).lowercased()).\n\n\(sourceLabel(serving.source))")
            }
        }
    }

    // Normalize generic source wording only for display; preserve the stored label.
    private func displayLabel(_ raw: String) -> String {
        let label = PortionDisplay.label(raw)
        return label.lowercased() == "porsjon" ? "Porsjon" : label
    }

    private var countLabel: some View {
        Text("Antall")
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.ink)
    }

    private var countControls: some View {
        AmountInputRow(title: "Antall", gramsText: $model.text, unit: "", showsTitle: false,
                       controlWidth: amountControlWidth)
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
                       gramsText: $model.text, unit: model.selectedServing == nil ? model.unit.rawValue : "",
                       controlWidth: amountControlWidth)
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
