import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    @EnvironmentObject var userDataExportService: UserDataExportService
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    NavigationLink("Personlige detaljer") {
                        PersonalDetailsView()
                            .environmentObject(appState)
                    }
                    
                    NavigationLink("Personvern & valg") {
                        PrivacyChoicesView()
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
                    if let email = authViewModel.currentUser?.email, !email.isEmpty {
                        HStack {
                            Text("E-post")
                            Spacer()
                            Text(email)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Button("Last ned data") {
                        Task {
                            guard let user = authViewModel.currentUser else { return }
                            exportURL = await userDataExportService.export(for: user)
                            showShareSheet = exportURL != nil
                        }
                    }
                    
                    Button("Logg ut", role: .destructive) {
                        authViewModel.logout()
                    }
                    
                    Button("Slett konto", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
                
                Section("Mål") {
                    if let goal = healthProfileViewModel.currentGoal {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nåværende mål")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            if preferencesViewModel.safeModeHideCalories {
                                Text("Mål per dag er satt")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                            } else {
                                Text("\(goal.dailyCalories) kcal per dag")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                            }
                            
                            Text("Protein \(Int(goal.proteinTargetG)) g · Karbohydrater \(Int(goal.carbsTargetG)) g · Fett \(Int(goal.fatTargetG)) g")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    NavigationLink("Endre mål") {
                        GoalOnboardingFlowView(mode: .edit)
                            .environmentObject(appState)
                    }
                    
                    Toggle("Vis målstatus på Home", isOn: $preferencesViewModel.showGoalStatusOnHome)
                }
                
                Section("Preferanser") {
                    Toggle("Haptics", isOn: $preferencesViewModel.hapticsFeedbackEnabled)
                    Toggle("Lyd", isOn: $preferencesViewModel.soundFeedbackEnabled)
                    Toggle("Vis datakilde", isOn: $preferencesViewModel.showNutritionSource)
                    
                    HStack {
                        Text("Enheter")
                        Spacer()
                        Text("Gram")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Section("Trygghet") {
                    Toggle("Trygg modus", isOn: $preferencesViewModel.safeModeEnabled)
                    Text("For en roligere visning")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if !preferencesViewModel.safeModeEnabled {
                        Toggle("Skjul kalorier", isOn: $preferencesViewModel.safeModeHideCalories)
                        Toggle("Skjul mål/progresjon", isOn: $preferencesViewModel.safeModeHideGoals)
                    }
                }
                
                Section("Data & synk") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(syncStatusText)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let error = appState.lastSyncError, appState.lastSyncSucceeded == false {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Button("Forsøk synk") {
                        Task { await appState.triggerSync(reason: .userInitiated) }
                    }
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
                Task { await appState.refreshSyncStatus() }
            }
            .alert("Slett konto?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) {
                    Task { await authViewModel.deleteAccount() }
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
        authViewModel.currentUser?.authProvider.capitalized ?? "Ukjent"
    }
    
    private var syncStatusText: String {
        if !FeatureFlags.backendSyncEnabled {
            if appState.pendingSyncCount == 0 {
                return "Venter på synk (backend ikke aktiv)"
            }
            return "\(appState.pendingSyncCount) venter på synk"
        }
        if appState.pendingSyncCount > 0 {
            return "\(appState.pendingSyncCount) venter på synk"
        }
        if appState.lastSyncSucceeded == true {
            return "Alt synket"
        }
        if appState.lastSyncSucceeded == false {
            return "Synk feilet"
        }
        return "Venter på synk"
    }
    
    private var personalSummary: String? {
        let details = healthProfileViewModel.personalDetails
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
