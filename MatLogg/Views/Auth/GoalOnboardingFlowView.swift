import SwiftUI

struct GoalOnboardingFlowView: View {
    enum Mode {
        case onboarding
        case edit
    }
    
    enum Step: Int, CaseIterable {
        case intent
        case pace
        case activity
        case data
        case result
        case macros
        case summary
    }
    
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let mode: Mode
    
    @State private var step: Step = .intent
    @State private var intent: GoalIntent = .maintain
    @State private var pace: GoalPace = .calm
    @State private var activity: ActivityLevel = .moderat
    @State private var gender: GenderOption = .ikkeOppgi
    @State private var weightText = ""
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var kcalTarget: Int = 2000
    @State private var macroPreset: MacroPreset = .balanced
    @State private var proteinText = ""
    @State private var carbsText = ""
    @State private var fatText = ""
    @State private var didSetInitialCalories = false
    @State private var didAdjustCalories = false
    @State private var lastSuggestedCalories: Int = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header
                
                Spacer()
                
                switch step {
                case .intent:
                    intentStep
                case .pace:
                    paceStep
                case .activity:
                    activityStep
                case .data:
                    dataStep
                case .result:
                    resultStep
                case .macros:
                    macroStep
                case .summary:
                    summaryStep
                }
                
                Spacer()
                
                footer
            }
            .padding(20)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if mode == .edit {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Lukk") { dismiss() }
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .onAppear {
                loadDefaults()
            }
            .onChange(of: intent) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: pace) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: activity) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: weightText) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: heightText) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: ageText) { _, _ in
                refreshSuggestedCalories()
            }
            .onChange(of: gender) { _, _ in
                refreshSuggestedCalories()
            }
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Mål")
                .font(AppTypography.title)
                .foregroundColor(AppColors.ink)
            Text("Du kan endre dette når som helst.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var footer: some View {
        HStack(spacing: 12) {
            if step != .intent {
                Button("Tilbake") {
                    withAnimation {
                        step = Step(rawValue: step.rawValue - 1) ?? .intent
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(AppColors.surface)
                .foregroundColor(AppColors.ink)
                .cornerRadius(12)
            }
            
            Button(action: nextAction) {
                Text(step == .summary ? "Fullfør" : "Neste")
                    .font(AppTypography.bodyEmphasis)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(AppColors.brand)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
    
    private var intentStep: some View {
        VStack(spacing: 12) {
            intentCard(.lose)
            intentCard(.maintain)
            intentCard(.gain)
        }
    }
    
    private func intentCard(_ option: GoalIntent) -> some View {
        Button(action: { intent = option }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    Text("Du kan endre dette når som helst.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if intent == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.brand)
                }
            }
            .padding(12)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
    
    private var paceStep: some View {
        VStack(spacing: 12) {
            paceCard(.calm)
            paceCard(.standard)
            paceCard(.fast)
        }
    }
    
    private func paceCard(_ option: GoalPace) -> some View {
        Button(action: { pace = option }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.label)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    if let note = option.note {
                        Text(note)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                if pace == option {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.brand)
                }
            }
            .padding(12)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
    
    private var activityStep: some View {
        VStack(spacing: 12) {
            ForEach([ActivityLevel.lav, .moderat, .hoy, .veldigHoy], id: \.self) { level in
                Button(action: { activity = level }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(level.label)
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                            Text(level.description)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        Spacer()
                        if activity == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.brand)
                        }
                    }
                    .padding(12)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var dataStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Valgfritt")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            
            VStack(spacing: 12) {
                if !appState.safeModeEnabled {
                    TextField("Vekt (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Høyde (cm)", text: $heightText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                TextField("Alder (år)", text: $ageText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Kjønn", selection: $gender) {
                    ForEach(GenderOption.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Button("Hopp over") {
                withAnimation {
                    if !didAdjustCalories {
                        kcalTarget = suggestedCalories()
                        didSetInitialCalories = true
                    }
                    step = .result
                }
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.brand)
        }
    }
    
    private var resultStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if appState.safeModeEnabled {
                Text("Forslått mål: \(GoalCalculator.roundedDisplay(kcalTarget))")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.ink)
            } else {
                Text("Forslått mål: \(GoalCalculator.roundedDisplay(kcalTarget)) kcal/dag")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.ink)
            }
            
            Text("Basert på valgene dine. Du kan justere.")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
            
            Text("Juster selv")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            
            HStack(spacing: 8) {
                Button(action: { kcalTarget = GoalCalculator.clampCalories(kcalTarget - 100) }) {
                    Text("− 100")
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded { didAdjustCalories = true })
                
                Button(action: { kcalTarget = GoalCalculator.clampCalories(kcalTarget - 50) }) {
                    Text("− 50")
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded { didAdjustCalories = true })
                
                TextField("", text: Binding(
                    get: { String(kcalTarget) },
                    set: {
                        kcalTarget = Int($0.filter(\.isNumber)) ?? kcalTarget
                        didAdjustCalories = true
                    }
                ))
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                
                Button(action: { kcalTarget = GoalCalculator.clampCalories(kcalTarget + 50) }) {
                    Text("+ 50")
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded { didAdjustCalories = true })
                
                Button(action: { kcalTarget = GoalCalculator.clampCalories(kcalTarget + 100) }) {
                    Text("+ 100")
                }
                .buttonStyle(.bordered)
                .simultaneousGesture(TapGesture().onEnded { didAdjustCalories = true })
            }
        }
        .onAppear {
            if !didSetInitialCalories {
                kcalTarget = suggestedCalories()
                didSetInitialCalories = true
            }
        }
    }
    
    private var macroStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MacroPreset.allCases, id: \.self) { preset in
                Button(action: { macroPreset = preset }) {
                    HStack {
                        Text(preset.label)
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Spacer()
                        if macroPreset == preset {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.brand)
                        }
                    }
                    .padding(12)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
            }
            
            if macroPreset == .custom {
                VStack(spacing: 12) {
                    TextField("Protein (g)", text: $proteinText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Karbohydrater (g)", text: $carbsText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                    TextField("Fett (g)", text: $fatText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }
    
    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Oppsummering")
                .font(AppTypography.title)
                .foregroundColor(AppColors.ink)
            
            if appState.safeModeEnabled {
                Text("Mål per dag: \(kcalTarget)")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                Text("Mål: \(kcalTarget) kcal/dag")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            let macros = selectedMacros()
            Text("Protein: \(Int(macros.proteinG)) g")
            Text("Karbohydrater: \(Int(macros.carbsG)) g")
            Text("Fett: \(Int(macros.fatG)) g")
        }
        .font(AppTypography.body)
        .foregroundColor(AppColors.ink)
    }
    
    private func nextAction() {
        if step == .summary {
            saveGoal()
            return
        }
        withAnimation {
            let nextStep = Step(rawValue: step.rawValue + 1) ?? .summary
            if nextStep == .result, !didAdjustCalories {
                kcalTarget = suggestedCalories()
                didSetInitialCalories = true
            }
            step = nextStep
        }
    }
    
    private func suggestedCalories() -> Int {
        let input = GoalCalculationInput(
            weightKg: parseNumber(weightText),
            heightCm: parseNumber(heightText),
            ageYears: Int(ageText.filter(\.isNumber)),
            gender: gender == .ikkeOppgi ? nil : gender,
            activity: activity,
            intent: intent,
            pace: pace
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        return GoalCalculator.roundedDisplay(result.suggestedCalories)
    }
    
    private func selectedMacros() -> MacroTargets {
        let custom = MacroTargets(
            proteinG: Float(parseNumber(proteinText) ?? 0),
            carbsG: Float(parseNumber(carbsText) ?? 0),
            fatG: Float(parseNumber(fatText) ?? 0)
        )
        return GoalCalculator.calculateMacros(kcal: kcalTarget, preset: macroPreset, custom: custom)
    }
    
    private func loadDefaults() {
        if let goal = appState.currentGoal {
            kcalTarget = goal.dailyCalories
            intent = goal.intent ?? .maintain
            pace = goal.pace ?? .calm
            activity = goal.activityLevel ?? .moderat
            didSetInitialCalories = true
            didAdjustCalories = true
        }
        let details = appState.personalDetails
        if let weight = details.weightKg {
            weightText = formatNumber(weight)
        }
        if let height = details.heightCm {
            heightText = formatNumber(height)
        }
        if let gender = details.gender {
            self.gender = gender
        }
    }
    
    private func saveGoal() {
        guard let user = appState.currentUser else {
            dismiss()
            return
        }
        let macros = selectedMacros()
        let goal = Goal(
            userId: user.id,
            goalType: intent == .lose ? "weight_loss" : intent == .gain ? "gain" : "maintain",
            dailyCalories: kcalTarget,
            proteinTargetG: macros.proteinG,
            carbsTargetG: macros.carbsG,
            fatTargetG: macros.fatG,
            intent: intent,
            pace: pace,
            activityLevel: activity,
            safeModeEnabled: appState.safeModeEnabled
        )
        
        var updatedDetails = appState.personalDetails
        if !appState.safeModeEnabled, let weight = parseNumber(weightText) {
            updatedDetails.weightKg = weight
        }
        if let height = parseNumber(heightText) {
            updatedDetails.heightCm = height
        }
        if let age = Int(ageText.filter(\.isNumber)), let birthDate = birthDateFromAge(age) {
            updatedDetails.birthDate = birthDate
        }
        updatedDetails.gender = gender == .ikkeOppgi ? nil : gender
        updatedDetails.activityLevel = activity
        appState.personalDetails = updatedDetails
        
        Task {
            try? await DatabaseService.shared.saveGoal(goal)
            appState.currentGoal = goal
            appState.isOnboarding = false
            dismiss()
        }
    }
    
    private func parseNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
    
    private func birthDateFromAge(_ age: Int) -> Date? {
        Calendar.current.date(byAdding: .year, value: -age, to: Date())
    }
    
    private func refreshSuggestedCalories() {
        guard !didAdjustCalories else { return }
        let suggested = suggestedCalories()
        if suggested != lastSuggestedCalories || !didSetInitialCalories {
            kcalTarget = suggested
            lastSuggestedCalories = suggested
            didSetInitialCalories = true
        }
    }
}
