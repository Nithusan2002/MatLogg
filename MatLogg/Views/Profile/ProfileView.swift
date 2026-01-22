import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    @State private var dailyCalories = ""
    @State private var proteinTarget = ""
    @State private var carbsTarget = ""
    @State private var fatTarget = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    NavigationLink("Personlige detaljer") {
                        PersonalDetailsView()
                            .environmentObject(appState)
                    }
                    
                    NavigationLink("Fremgang") {
                        ProgressTabView()
                            .environmentObject(appState)
                    }
                    
                    if let summary = personalSummary {
                        Text(summary)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Section("Konto") {
                    HStack {
                        Text("Innlogging")
                        Spacer()
                        Text(authProviderLabel)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let email = appState.currentUser?.email, !email.isEmpty {
                        HStack {
                            Text("E-post")
                            Spacer()
                            Text(email)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Button("Last ned data") {
                        Task {
                            exportURL = await appState.exportUserData()
                            showShareSheet = exportURL != nil
                        }
                    }
                    
                    Button("Logg ut", role: .destructive) {
                        appState.logout()
                    }
                    
                    Button("Slett konto", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
                
                Section("Mål") {
                    TextField("Kalorier per dag", text: $dailyCalories)
                        .keyboardType(.numberPad)
                    TextField("Protein (g)", text: $proteinTarget)
                        .keyboardType(.decimalPad)
                    TextField("Karbohydrater (g)", text: $carbsTarget)
                        .keyboardType(.decimalPad)
                    TextField("Fett (g)", text: $fatTarget)
                        .keyboardType(.decimalPad)
                    
                    Toggle("Vis målstatus på Home", isOn: $appState.showGoalStatusOnHome)
                    
                    Button("Lagre mål") {
                        saveGoals()
                    }
                    .foregroundColor(AppColors.brand)
                }
                
                Section("Preferanser") {
                    Toggle("Haptics", isOn: $appState.hapticsFeedbackEnabled)
                    Toggle("Lyd", isOn: $appState.soundFeedbackEnabled)
                    Toggle("Vis datakilde", isOn: $appState.showNutritionSource)
                    
                    HStack {
                        Text("Enheter")
                        Spacer()
                        Text("Gram")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Section("Trygghet") {
                    Toggle("Trygg modus", isOn: $appState.safeModeEnabled)
                    Text("For en roligere visning")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if !appState.safeModeEnabled {
                        Toggle("Skjul kalorier", isOn: $appState.safeModeHideCalories)
                        Toggle("Skjul mål/progresjon", isOn: $appState.safeModeHideGoals)
                    }
                }
                
                Section("Data & synk") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Alt synket")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Button("Prøv igjen nå") {}
                        .foregroundColor(AppColors.brand)
                    
                    CardContainer {
                        Text("Offline-first: Du kan logge uten nett. Synk skjer når nettet er tilbake.")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                #if DEBUG
                Section("Debug") {
                    NavigationLink("Theme Preview") {
                        ThemePreviewView()
                    }
                }
                #endif
            }
            .navigationTitle("Profil")
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                loadGoalFields()
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.brand)
                }
            }
            .alert("Slett konto?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) {
                    Task { await appState.deleteAccount() }
                }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Dette kan ikke angres.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let exportURL {
                    ShareSheet(activityItems: [exportURL])
                }
            }
        }
    }
    
    private var authProviderLabel: String {
        appState.currentUser?.authProvider.capitalized ?? "Ukjent"
    }
    
    private func loadGoalFields() {
        guard let goal = appState.currentGoal else { return }
        dailyCalories = String(goal.dailyCalories)
        proteinTarget = String(format: "%.0f", goal.proteinTargetG)
        carbsTarget = String(format: "%.0f", goal.carbsTargetG)
        fatTarget = String(format: "%.0f", goal.fatTargetG)
    }
    
    private func saveGoals() {
        guard let user = appState.currentUser else { return }
        let calories = Int(dailyCalories) ?? appState.currentGoal?.dailyCalories ?? 0
        let protein = Float(proteinTarget.replacingOccurrences(of: ",", with: ".")) ?? appState.currentGoal?.proteinTargetG ?? 0
        let carbs = Float(carbsTarget.replacingOccurrences(of: ",", with: ".")) ?? appState.currentGoal?.carbsTargetG ?? 0
        let fat = Float(fatTarget.replacingOccurrences(of: ",", with: ".")) ?? appState.currentGoal?.fatTargetG ?? 0
        
        let goal = Goal(
            userId: user.id,
            goalType: appState.currentGoal?.goalType ?? "maintain",
            dailyCalories: calories,
            proteinTargetG: protein,
            carbsTargetG: carbs,
            fatTargetG: fat
        )
        appState.currentGoal = goal
    }
    
    private var personalSummary: String? {
        let details = appState.personalDetails
        var parts: [String] = []
        
        if let weight = details.weightKg {
            parts.append("\(formatNumber(weight)) kg")
        }
        if let height = details.heightCm {
            parts.append("\(formatNumber(height)) cm")
        }
        if let gender = details.gender {
            parts.append(gender.label)
        }
        if let activity = details.activityLevel {
            parts.append(activity.label)
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }
    
    private func formatNumber(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
