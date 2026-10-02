import SwiftUI

struct MatLoggOnboardingFlowView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel

    @State private var showMeasurement: PersonalMeasurement?
    @State private var showPrivacyPolicy = false
    @State private var showPrivacyChoices = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollView {
                    stepContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
                .id(onboardingViewModel.step)
                .scrollDismissesKeyboard(.interactively)
                footer
            }
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.action)
            .navigationBarBackButtonHidden(true)
            .onAppear(perform: beginIfPossible)
            .sheet(item: $showMeasurement) { measurement in
                MeasurementPickerSheet(
                    measurement: measurement,
                    initialText: measurement == .weight ? onboardingViewModel.weightText : onboardingViewModel.heightText,
                    explanation: "Brukes til et veiledende målforslag. Opplysningen lagres først når du fullfører oppsettet."
                ) { value in
                    if measurement == .weight { onboardingViewModel.weightText = value }
                    else { onboardingViewModel.heightText = value }
                }
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                if let url = PrivacyConstants.privacyPolicyURL {
                    SafariView(url: url)
                }
            }
            .sheet(isPresented: $showPrivacyChoices) {
                if let url = PrivacyConstants.privacyChoicesURL {
                    SafariView(url: url)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if onboardingViewModel.canGoBack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onboardingViewModel.back()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .foregroundColor(AppColors.ink)
                    .accessibilityLabel("Tilbake")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MatLogg")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.deepInk)
                    if let progressText = onboardingViewModel.progressText {
                        Text(progressText)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
            }
            if onboardingViewModel.progressText != nil {
                GeometryReader { geometry in
                    Capsule()
                        .fill(AppColors.progressTrack)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.brand)
                                .frame(width: geometry.size.width * onboardingViewModel.progressFraction)
                        }
                }
                .frame(height: 6)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(onboardingViewModel.progressText ?? "")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(AppColors.background)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch onboardingViewModel.step {
        case .introduction:
            introductionStep
        case .intent:
            intentStep
        case .goalSetup:
            goalSetupStep
        case .personalDetails:
            personalDetailsStep
        case .result:
            resultStep
        case .macros:
            macrosStep
        case .privacy:
            privacyStep
        case .summary:
            summaryStep
        }
    }

    private var introductionStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle(
                eyebrow: "PÅ DINE PREMISSER",
                title: "Logg mat på din måte",
                body: "Kalorier og næringsverdier gir oversikt, mens mål og personlige opplysninger er valgfrie."
            )
            VStack(spacing: 12) {
                TrustCard(title: "Lagres på denne iPhonen", message: "Du kan bruke matloggen uten konto eller nett.", systemImage: "iphone")
                TrustCard(title: "Valgfrie opplysninger", message: "Du bestemmer selv hva du vil legge inn.", systemImage: "slider.horizontal.3")
                TrustCard(title: "Ingen medisinske råd", message: "Dette er en logg og oversikt, ikke behandling.", systemImage: "heart")
            }
        }
    }

    private var intentStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle(
                eyebrow: "FORMÅL",
                title: "Hva ønsker du oversikt over?",
                body: "Valget brukes bare til å forme oversikten din."
            )
            VStack(spacing: 12) {
                ForEach(OnboardingViewModel.IntentChoice.allCases) { choice in
                    ChoiceCard(
                        title: choice.title,
                        description: choice.description,
                        isSelected: onboardingViewModel.intent == choice
                    ) {
                        onboardingViewModel.intent = choice
                    }
                }
            }
        }
    }

    private var goalSetupStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            stepTitle(
                eyebrow: "VALGFRITT UTGANGSPUNKT",
                title: "Tempo og aktivitet",
                body: "Vi bruker valgene dine til å foreslå et kalorimål."
            )
            optionSection(title: "Ønsket tempo") {
                ForEach(GoalPace.allCases, id: \.self) { pace in
                    ChoiceCard(
                        title: pace.label,
                        description: pace.note,
                        isSelected: onboardingViewModel.pace == pace
                    ) {
                        onboardingViewModel.pace = pace
                    }
                }
            }
            optionSection(title: "Aktivitet i hverdagen") {
                ForEach([ActivityLevel.lav, .moderat, .hoy, .veldigHoy], id: \.self) { activity in
                    ChoiceCard(
                        title: activity.label,
                        description: activity.description,
                        isSelected: onboardingViewModel.activity == activity
                    ) {
                        onboardingViewModel.activity = activity
                    }
                }
            }
        }
    }

    private func measurementCard(_ measurement: PersonalMeasurement, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(measurement.title) (\(measurement.unit))")
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.ink)
            Button {
                showMeasurement = measurement
            } label: {
                HStack(spacing: 12) {
                    Text(text.isEmpty ? "Velg " + measurement.title.lowercased() : text + " " + measurement.unit)
                        .font(AppTypography.body)
                        .foregroundStyle(text.isEmpty ? AppColors.textSecondary : AppColors.ink)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(AppTypography.captionEmphasis)
                        .foregroundStyle(AppColors.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(minHeight: 48)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.controlBorder, lineWidth: 1))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(measurement.title + ", " + measurement.unit)
            .accessibilityValue(text.isEmpty ? "Ikke oppgitt" : text)
            .accessibilityHint("Åpner tallskala og direkte inntasting.")
            .accessibilityIdentifier("onboarding-" + measurement.rawValue)
        }
    }

    private var personalDetailsStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "VALGFRITT",
                title: "Vil du ha et forslag til kalorimål?",
                body: "Opplysningene lagres på profilen din og brukes bare til målberegningen."
            )
            measurementCard(.weight, text: onboardingViewModel.weightText)
            measurementCard(.height, text: onboardingViewModel.heightText)
            InputCard(label: "Alder", unit: "år", text: $onboardingViewModel.ageText, keyboard: .numberPad)
            VStack(alignment: .leading, spacing: 8) {
                Text("Kjønn")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.ink)
                Picker("Kjønn", selection: $onboardingViewModel.gender) {
                    ForEach(GenderOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            Text("Vi bruker kjønn når vi beregner et forslag til kalorimål. Velger du Annet eller Ønsker ikke å oppgi, kan du sette målet selv.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            if onboardingViewModel.isManualTarget || onboardingViewModel.suggestion == nil {
                stepTitle(
                    eyebrow: "DAGSMÅL",
                    title: onboardingViewModel.suggestion == nil && !onboardingViewModel.isManualTarget ? "Ikke nok opplysninger" : "Angi eget mål",
                    body: onboardingViewModel.suggestion == nil && !onboardingViewModel.isManualTarget
                        ? "Vi kan ikke beregne et personlig forslag med disse opplysningene. Vi gjetter ikke et standardtall."
                        : "Velg et mål du selv ønsker å bruke."
                )
                if onboardingViewModel.isManualTarget {
                    InputCard(label: "Eget mål", unit: "kcal per dag", text: $onboardingViewModel.calorieTargetText, keyboard: .numberPad)
                } else {
                    Button("Angi eget mål") {
                        onboardingViewModel.useManualTarget()
                    }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.action)
                    .frame(minHeight: 44)
                }
            } else {
                stepTitle(
                    eyebrow: "FORSLAG TIL KALORIMÅL",
                    title: "Ca. \(onboardingViewModel.calorieTarget ?? 0) kcal per dag",
                    body: "Et forslag basert på det du har oppgitt, ikke en medisinsk anbefaling."
                )
                HStack(spacing: 8) {
                    adjustmentButton(-100)
                    adjustmentButton(-50)
                    adjustmentButton(50)
                    adjustmentButton(100)
                }
                InputCard(label: "Juster selv", unit: "kcal per dag", text: $onboardingViewModel.calorieTargetText, keyboard: .numberPad)
            }
            if onboardingViewModel.attemptedResult && !onboardingViewModel.hasValidCalorieTarget {
                validationText("Skriv et heltall mellom 1200 og 4500 kcal. Dette er grenser i appen, ikke en medisinsk anbefaling.")
            }
        }
    }

    private var macrosStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepTitle(
                eyebrow: "NÆRINGSOVERSIKT",
                title: "Velg fordeling av næringsstoffer",
                body: "Velg hvordan målet fordeles mellom protein, karbohydrater og fett. Dette er generelle forslag for voksne, ikke personlige ernæringsråd."
            )
            VStack(spacing: 12) {
                ForEach(MacroPreset.allCases, id: \.self) { preset in
                    ChoiceCard(title: preset.label, isSelected: onboardingViewModel.macroPreset == preset) {
                        onboardingViewModel.macroPreset = preset
                    }
                }
            }
            if onboardingViewModel.macroPreset == .custom {
                InputCard(label: "Protein", unit: "g per dag", text: $onboardingViewModel.proteinText, keyboard: .decimalPad)
                InputCard(label: "Karbohydrater", unit: "g per dag", text: $onboardingViewModel.carbsText, keyboard: .decimalPad)
                InputCard(label: "Fett", unit: "g per dag", text: $onboardingViewModel.fatText, keyboard: .decimalPad)
                if onboardingViewModel.attemptedMacros && !onboardingViewModel.hasValidMacros {
                    validationText("Fyll inn gram mellom 0 og 999 for alle tre næringsstoffene.")
                }
            }
        }
    }

    private var privacyStep: some View {
        PrivacyChoicesContentView(
            onOpenPolicy: PrivacyConstants.privacyPolicyURL == nil ? nil : { showPrivacyPolicy = true },
            onOpenChoices: PrivacyConstants.privacyChoicesURL == nil ? nil : { showPrivacyChoices = true }
        )
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            stepTitle(
                eyebrow: "OPPSUMMERING",
                title: "Slik blir oversikten din",
                body: "Alt kan justeres senere i Innstillinger og Profil."
            )
            SummaryCard(title: "Mål", value: onboardingViewModel.goalSummary) {
                onboardingViewModel.edit(.intent)
            }
            if onboardingViewModel.shouldCreateGoal {
                SummaryCard(title: "Næringsoversikt", value: onboardingViewModel.macroSummary) {
                    onboardingViewModel.edit(.macros)
                }
            }
            CardContainer {
                Label("Oppsettet lagres først på denne enheten.", systemImage: "iphone")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.ink)
            }
            if let errorMessage = onboardingViewModel.errorMessage {
                validationText(errorMessage)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            PrimaryButton(title: onboardingViewModel.primaryButtonTitle) {
                primaryAction()
            }
            .disabled(onboardingViewModel.isSaving)
            .opacity(onboardingViewModel.isSaving ? 0.6 : 1)
            .accessibilityIdentifier("onboarding-primary")

            switch onboardingViewModel.step {
            case .introduction:
                Button("Start uten mål") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboardingViewModel.chooseQuickStart()
                    }
                }
                .secondaryOnboardingAction()
            case .personalDetails:
                Button("Angi eget mål") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboardingViewModel.continueWithManualTarget()
                    }
                }
                .secondaryOnboardingAction()
                Button("Fortsett uten mål") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboardingViewModel.continueWithoutGoal()
                    }
                }
                .secondaryOnboardingAction()
            case .result:
                Button("Fortsett uten mål") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onboardingViewModel.continueWithoutGoal()
                    }
                }
                .secondaryOnboardingAction()
            default:
                EmptyView()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private func beginIfPossible() {
        guard let userId = authViewModel.currentUser?.id else { return }
        onboardingViewModel.begin(
            userId: userId,
            goal: healthProfileViewModel.currentGoal,
            details: healthProfileViewModel.personalDetails
        )
    }

    private func primaryAction() {
        if onboardingViewModel.step == .summary {
            completeOnboarding()
            return
        }
        if onboardingViewModel.step == .privacy {
            preferencesViewModel.hasSeenPrivacyChoices = true
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            onboardingViewModel.advance()
        }
    }

    private func completeOnboarding() {
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            guard let result = await onboardingViewModel.complete(userId: userId) else {
                appState.errorMessage = onboardingViewModel.errorMessage
                return
            }
            preferencesViewModel.hasSeenPrivacyChoices = true
            healthProfileViewModel.acceptOnboardingCompletion(
                goal: result.goal,
                personalDetails: result.personalDetails
            )
            authViewModel.finishOnboarding()
        }
    }

    private func stepTitle(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(AppTypography.captionEmphasis)
                .foregroundColor(AppColors.action)
            Text(title)
                .font(AppTypography.hero)
                .foregroundColor(AppColors.deepInk)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private func optionSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(AppTypography.sectionTitle)
                .foregroundColor(AppColors.ink)
            VStack(spacing: 10, content: content)
        }
    }

    private func adjustmentButton(_ amount: Int) -> some View {
        Button(amount > 0 ? "+ \(amount)" : "− \(abs(amount))") {
            onboardingViewModel.adjustCalories(by: amount)
        }
        .font(AppTypography.bodyEmphasis)
        .foregroundColor(AppColors.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.controlBorder, lineWidth: 1))
    }

    private func validationText(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(AppTypography.caption)
            .foregroundColor(AppColors.action)
            .accessibilityElement(children: .combine)
    }
}

private struct ChoiceCard: View {
    let title: String
    var description: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    if let description {
                        Text(description)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppColors.brand : AppColors.controlBorder)
                    .accessibilityHidden(true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(isSelected ? AppColors.chipFillSelected : AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppColors.brand : AppColors.separator, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Valgt" : "Ikke valgt")
    }
}

private struct TrustCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundColor(AppColors.action)
                    .frame(width: 36, height: 36)
                    .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.bodyEmphasis)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .foregroundColor(AppColors.ink)
            }
        }
    }
}

private struct InputCard: View {
    let label: String
    let unit: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(label) (\(unit))")
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
            TextField("—", text: $text)
                .keyboardType(keyboard)
                .font(AppTypography.body)
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(AppColors.controlBorder, lineWidth: 1))
                .accessibilityLabel("\(label), \(unit)")
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let edit: () -> Void

    var body: some View {
        CardContainer {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                    Text(value)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                }
                Spacer()
                Button("Endre", action: edit)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.action)
                    .frame(minHeight: 44)
            }
        }
    }
}

private extension View {
    func secondaryOnboardingAction() -> some View {
        self
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.action)
            .frame(maxWidth: .infinity, minHeight: 44)
    }
}
