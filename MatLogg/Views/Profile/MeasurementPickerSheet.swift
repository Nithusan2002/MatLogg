import SwiftUI

struct MeasurementPickerSheet: View {
    @StateObject private var viewModel: MeasurementPickerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var editingValue: Bool
    let explanation: String?
    let onApply: (String) -> Void

    init(measurement: PersonalMeasurement, initialText: String, explanation: String? = nil, onApply: @escaping (String) -> Void) {
        _viewModel = StateObject(wrappedValue: MeasurementPickerViewModel(
            measurement: measurement, initialText: initialText))
        self.explanation = explanation
        self.onApply = onApply
    }

    private var measurement: PersonalMeasurement { viewModel.measurement }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                MatLoggSheetHeader(title: measurement.title, onClose: { dismiss() })

                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("Verdi", text: $viewModel.text)
                            .font(AppTypography.hero)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .focused($editingValue)
                            .accessibilityLabel(measurement.title + ", " + measurement.unit)
                            .accessibilityIdentifier("measurement-picker-value")
                        Text(measurement.unit)
                            .font(AppTypography.title)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: 240)
                    Text("Dra skalaen eller trykk på tallet.")
                        .font(AppTypography.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                    if let error = viewModel.error {
                        ErrorMessageView(error)
                            .font(AppTypography.secondary)
                            .accessibilityIdentifier("measurement-picker-error")
                    }
                }

                CardContainer {
                    ruler
                }

                Text(explanation ?? (measurement == .weight
                     ? "Dette er grunnlag for målforslag, ikke en registrering i vekthistorikken."
                     : "Høyden brukes som grunnlag for målforslag."))
                    .font(AppTypography.secondary)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                PrimaryButton(title: "Bruk verdi") {
                    if let value = viewModel.confirmedText() {
                        onApply(value)
                        dismiss()
                    }
                }
                .accessibilityIdentifier("measurement-picker-apply")

                Button("Fjern opplysningen") {
                    onApply("")
                    dismiss()
                }
                .font(AppTypography.bodyEmphasis)
                .frame(minHeight: 44)
                .accessibilityIdentifier("measurement-picker-clear")
            }
            .padding(16)
        }
        .accessibilityIdentifier("measurement-picker-sheet")
        .background(AppColors.background.ignoresSafeArea())
        .foregroundStyle(AppColors.ink)
        .tint(AppColors.action)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { editingValue = false }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(640), .large])
        .presentationDragIndicator(.visible)
    }

    private var ruler: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 0) {
                    ForEach(0..<measurement.tickCount, id: \.self) { tick in
                        let major = tick.isMultiple(of: measurement.majorInterval)
                        VStack(spacing: 12) {
                            Rectangle()
                                .fill(major ? AppColors.ink : AppColors.textSecondary)
                                .frame(width: major ? 2 : 1, height: major ? 38 : 20)
                            if major {
                                Text(measurement.value(at: tick).formatted(.number.precision(.fractionLength(0))))
                                    .font(AppTypography.caption)
                                    .fixedSize()
                            }
                        }
                        .frame(width: 12, height: 90, alignment: .top)
                        .id(tick)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(0, (geometry.size.width - 12) / 2), for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: Binding<Int?>(
                get: { viewModel.selectedTick },
                set: { if let tick = $0 { viewModel.select(tick: tick) } }
            ), anchor: .center)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(AppColors.action)
                    .frame(width: 3, height: 48)
                    .offset(y: -6)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 100)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(measurement.title)
        .accessibilityValue(viewModel.text + " " + measurement.unit)
        .accessibilityHint("Sveip opp eller ned for å justere verdien.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: viewModel.adjust(by: 1)
            case .decrement: viewModel.adjust(by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("measurement-picker-ruler")
    }
}
