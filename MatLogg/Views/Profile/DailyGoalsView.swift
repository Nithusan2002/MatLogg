import SwiftUI

struct DailyGoalsView: View {
    @EnvironmentObject private var viewModel: DailyGoalsViewModel
    @EnvironmentObject private var healthProfile: HealthProfileViewModel
    @EnvironmentObject private var preferences: PreferencesViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: DailyGoalsViewModel.Field?
    @State private var initialized = false
    @State private var showSuggestion = false

    private var hideGoals: Bool { preferences.safeModeEnabled || preferences.safeModeHideGoals }
    private var hideCalories: Bool { preferences.safeModeEnabled || preferences.safeModeHideCalories }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if hideGoals {
                    Text("Du har valgt en visning uten mål. Du kan endre visningen i Profil → Innstillinger.")
                        .foregroundStyle(AppColors.textSecondary)
                } else if hideCalories && !viewModel.hasGoal {
                    Text("For å sette opp daglige mål må du først slå på kalorivisning i Profil → Innstillinger.")
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text(viewModel.hasGoal ? "Juster målene dine. Endringene lagres først når du trykker Lagre endringer." : "Du har ikke satt opp mål ennå. Fyll inn egne verdier eller beregn et veiledende forslag.")
                        .foregroundStyle(AppColors.textSecondary)
                    CardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            if !hideCalories {
                                goalField("Kalorier", unit: "kcal/dag", field: .calories, text: $viewModel.calories)
                            }
                            goalField("Protein", unit: "g/dag", field: .protein, text: $viewModel.protein)
                            goalField("Karbohydrater", unit: "g/dag", field: .carbs, text: $viewModel.carbs)
                            goalField("Fett", unit: "g/dag", field: .fat, text: $viewModel.fat)
                        }
                    }
                    if !hideCalories {
                        Button("Beregn nytt forslag") {
                            focusedField = nil
                            showSuggestion = true
                        }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("daily-goals-suggest")
                    }
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundStyle(AppColors.ink)
                            .accessibilityIdentifier("daily-goals-error")
                    }
                    PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Lagre endringer") {
                        focusedField = nil
                        Task {
                            if await viewModel.save(hideGoals: hideGoals, hideCalories: hideCalories,
                                                    safeModeEnabled: preferences.safeModeEnabled) {
                                await appState.refreshSyncStatus()
                            }
                        }
                    }
                    .accessibilityIdentifier("daily-goals-save")
                    Text("Lagres på enheten, også uten nett. Målene er veiledende.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .font(AppTypography.body)
            .padding(20)
            .disabled(viewModel.isSaving || viewModel.didSave)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .navigationTitle("Daglige mål")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(hideGoals ? "Lukk" : "Avbryt") {
                    viewModel.discard()
                    dismiss()
                }
                .disabled(viewModel.isSaving)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { focusedField = nil }
            }
        }
        .onAppear {
            guard !initialized else { return }
            viewModel.begin(goal: healthProfile.currentGoal, userId: auth.currentUser?.id)
            initialized = true
        }
        .sheet(isPresented: $showSuggestion) {
            GoalSuggestionView(goal: healthProfile.currentGoal, details: healthProfile.personalDetails) {
                viewModel.apply($0)
            }
        }
        .alert("Målene er lagret på enheten", isPresented: Binding(
            get: { viewModel.didSave },
            set: { _ in }
        )) {
            Button("Ferdig") {
                viewModel.discard()
                dismiss()
            }
        }
    }

    private func goalField(_ title: String, unit: String, field: DailyGoalsViewModel.Field,
                           text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(unit))").font(AppTypography.bodyEmphasis)
            TextField(title, text: text)
                .keyboardType(field == .calories ? .numberPad : .decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 44)
                .focused($focusedField, equals: field)
                .accessibilityLabel("\(title), \(unit)")
                .accessibilityIdentifier("daily-goals-\(field)")
            if let error = viewModel.errors[field] {
                Text(error).font(AppTypography.caption)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }
}

private struct GoalSuggestionView: View {
    @StateObject private var viewModel: GoalSuggestionViewModel
    @EnvironmentObject private var preferences: PreferencesViewModel
    @Environment(\.dismiss) private var dismiss
    let onApply: (GoalSuggestion) -> Void

    init(goal: Goal?, details: PersonalDetails, onApply: @escaping (GoalSuggestion) -> Void) {
        _viewModel = StateObject(wrappedValue: GoalSuggestionViewModel(goal: goal, details: details))
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                if preferences.safeModeEnabled || preferences.safeModeHideGoals || preferences.safeModeHideCalories {
                    Text("Du har valgt en visning uten målforslag. Du kan endre visningen i Innstillinger.")
                        .listRowBackground(AppColors.surface)
                } else if viewModel.showingResult, let suggestion = viewModel.suggestion {
                    Section("Veiledende forslag") {
                        LabeledContent("Estimert startpunkt", value: "ca. \(suggestion.calories) kcal/dag")
                        LabeledContent("Protein", value: "\(suggestion.macros.proteinG.formatted(.number.precision(.fractionLength(0...1)))) g/dag")
                        LabeledContent("Karbohydrater", value: "\(suggestion.macros.carbsG.formatted(.number.precision(.fractionLength(0...1)))) g/dag")
                        LabeledContent("Fett", value: "\(suggestion.macros.fatG.formatted(.number.precision(.fractionLength(0...1)))) g/dag")
                        Text("Beregnet fra lagrede personopplysninger og valgene dine. Dette er et estimat, ikke en medisinsk anbefaling.")
                            .font(AppTypography.caption)
                    }
                    .listRowBackground(AppColors.surface)
                    Section {
                        Button("Bruk forslaget") {
                            onApply(suggestion)
                            dismiss()
                        }
                        .accessibilityIdentifier("daily-goals-apply-suggestion")
                        Button("Tilbake") { viewModel.showingResult = false }
                    } footer: {
                        Text("Forslaget fylles inn i utkastet. Trykk Lagre endringer på neste skjerm for å lagre.")
                    }
                    .listRowBackground(AppColors.surface)
                } else {
                    Section("Valgene dine") {
                        Picker("Måltype", selection: $viewModel.intent) {
                            ForEach(GoalIntent.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        if viewModel.intent != .maintain {
                            Picker("Tempo", selection: $viewModel.pace) {
                                ForEach(GoalPace.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        }
                        Picker("Aktivitetsnivå", selection: $viewModel.activity) {
                            ForEach(ActivityLevel.allCases, id: \.self) { Text($0.label).tag($0) }
                        }
                        Picker("Makrofordeling", selection: $viewModel.preset) {
                            ForEach([MacroPreset.balanced, .proteinFocus, .carbFocus], id: \.self) { Text($0.label).tag($0) }
                        }
                    }
                    .listRowBackground(AppColors.surface)
                    Section {
                        Button("Se forslag") { viewModel.showingResult = true }
                            .disabled(!viewModel.usesPersonalDetails)
                    } footer: {
                        Text(viewModel.usesPersonalDetails
                             ? "Bruker opplysningene i Personlige detaljer. Ingen mål eller personopplysninger endres før du lagrer på målskjermen. Ikke tilpasset graviditet, amming eller medisinske ernæringsbehov."
                             : viewModel.unavailableReason ?? "Oppdater Personlige detaljer eller angi egne mål.")
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.action)
            .navigationTitle("Beregn nytt forslag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
            }
        }
    }
}
