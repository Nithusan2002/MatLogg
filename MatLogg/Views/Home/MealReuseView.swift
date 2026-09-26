import SwiftUI

/// Presentation only: selection, validation and persistence belong to MealReuseViewModel.
struct MealReuseSuggestionView: View {
    let suggestion: MealReuseSuggestion
    let isSaving: Bool
    let hideCalories: Bool
    let onLog: () -> Void
    let onAdjust: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(suggestion.title)
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.ink)
            ForEach(suggestion.items) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(item.name) · \(item.original.amountG.formatted(.number.locale(Locale(identifier: "nb_NO")))) \(item.original.resolvedAmountUnit.rawValue)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !hideCalories {
                        Text("\(item.original.calories) kcal")
                            .foregroundStyle(AppColors.ink)
                    }
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: isSaving ? "Lagrer …" : "Loggfør", action: onLog)
                .accessibilityIdentifier("meal-reuse-log-\(suggestion.mealType)")
            ViewThatFits(in: .horizontal) {
                HStack { secondaryActions }
                VStack(alignment: .leading) { secondaryActions }
            }
        }
        .disabled(isSaving)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meal-reuse-suggestion-\(suggestion.mealType)")
    }

    @ViewBuilder private var secondaryActions: some View {
        Button("Juster", action: onAdjust)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("meal-reuse-adjust-\(suggestion.mealType)")
        Spacer(minLength: 12)
        Button("Ikke nå", action: onDismiss)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Skjul forslaget for dette måltidet i dag")
    }
}

struct MealReuseEditorView: View {
    @EnvironmentObject private var viewModel: MealReuseViewModel
    @EnvironmentObject private var preferences: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedItem: UUID?
    let onSaved: () async -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let draft = viewModel.draft {
                        Text(draft.title)
                            .font(AppTypography.title)
                        Text("Endre mengder eller fjern matvarer før du loggfører. Enhetene beholdes fra gårsdagens logg.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                        ForEach(draft.items) { item in
                            CardContainer {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(item.name)
                                        .font(AppTypography.bodyEmphasis)
                                    if preferences.showNutritionSource {
                                        Text("Kilde: \(sourceLabel(item.product.nutritionSource))")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Mengde (\(item.original.resolvedAmountUnit.rawValue))").font(AppTypography.body)
                                        TextField("Mengde i \(item.original.resolvedAmountUnit.spokenName)", text: Binding(
                                            get: { viewModel.draft?.items.first { $0.id == item.id }?.amountText ?? "" },
                                            set: { viewModel.setAmount(itemId: item.id, text: $0) }
                                        ))
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(minHeight: 44)
                                        .focused($focusedItem, equals: item.id)
                                        .accessibilityLabel("Mengde i \(item.original.resolvedAmountUnit.spokenName) for \(item.name)")
                                        .accessibilityIdentifier("meal-reuse-amount-\(item.id)")
                                    }
                                    if item.amountG == nil {
                                        Text("Skriv en mengde større enn 0 og høyst 10 000 \(item.original.resolvedAmountUnit.rawValue).")
                                            .font(AppTypography.caption)
                                    }
                                    Button("Fjern matvare", role: .destructive) {
                                        viewModel.removeItem(id: item.id)
                                    }
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("Fjern \(item.name) fra forslaget")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        if draft.items.isEmpty {
                            Text("Ingen matvarer igjen. Avbryt for å gå tilbake til vanlig logging.")
                                .font(AppTypography.body)
                        }
                        if let error = viewModel.errorMessage {
                            Text(error).font(AppTypography.body)
                                .accessibilityIdentifier("meal-reuse-editor-error")
                        }
                        PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Loggfør måltidet") {
                            focusedItem = nil
                            Task {
                                if await viewModel.logDraft() {
                                    dismiss()
                                    await onSaved()
                                }
                            }
                        }
                        .disabled(!viewModel.isDraftValid || viewModel.isSaving)
                        .accessibilityIdentifier("meal-reuse-save-draft")
                    }
                }
                .padding(16)
                .foregroundStyle(AppColors.ink)
                .disabled(viewModel.isSaving)
            }
            .background(AppColors.background)
            .navigationTitle("Juster måltidet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        viewModel.cancelEditing()
                        dismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { focusedItem = nil }
                }
            }
        }
        .interactiveDismissDisabled(viewModel.isSaving)
    }

    private func sourceLabel(_ source: NutritionSource) -> String {
        switch source {
        case .matvaretabellen: return "Matvaretabellen"
        case .openFoodFacts: return "Open Food Facts"
        case .user: return "Brukeroppgitt"
        }
    }
}
