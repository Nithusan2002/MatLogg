import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var productViewModel: ProductViewModel
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    @State private var favoriteCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Profil").font(AppTypography.hero).foregroundColor(AppColors.deepInk)
                    profileHeader
                    overviewCards
                    dailyGoalCard
                    shortcutCard
                    Label("Nappe · norsk matdagbok", systemImage: "flame.fill")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task(id: authViewModel.currentUser?.id) { await refreshProfileSummary() }
        }
    }

    private var profileHeader: some View {
        NavigationLink {
            PersonalDetailsView().environmentObject(appState)
        } label: {
            HStack(spacing: 18) {
                Text(profileInitials)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(AppColors.background)
                    .frame(width: 76, height: 76)
                    .background(AppColors.deepInk, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileName)
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.deepInk)
                        .lineLimit(2)
                    Text(todayLogLabel)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .profileCardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Åpner personlige detaljer")
    }

    private var overviewCards: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { overviewCardContents }
            VStack(spacing: 10) { overviewCardContents }
        }
    }

    @ViewBuilder private var overviewCardContents: some View {
        ProfileMetricCard(title: "MÅLTIDER I DAG", value: "\(mealCount)", tint: AppColors.brand, foreground: .white)
        ProfileMetricCard(title: "FAVORITTER", value: "\(favoriteCount)", tint: AppColors.accent, foreground: AppColors.onVibrant)
        ProfileMetricCard(title: "VENTER PÅ SYNK", value: "\(appState.pendingSyncCount)", tint: AppColors.success, foreground: AppColors.onVibrant)
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Dagens mål").font(AppTypography.title).foregroundColor(AppColors.deepInk)
            if preferencesViewModel.safeModeHideGoals {
                Label("Mål er skjult i Trygg modus", systemImage: "eye.slash")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else if let goal = healthProfileViewModel.currentGoal {
                if !preferencesViewModel.safeModeHideCalories {
                    GoalValueRow(label: "Kalorier", value: "\(goal.dailyCalories) kcal")
                }
                GoalValueRow(label: "Protein", value: "\(Int(goal.proteinTargetG)) g")
                GoalValueRow(label: "Karbohydrater", value: "\(Int(goal.carbsTargetG)) g")
                GoalValueRow(label: "Fett", value: "\(Int(goal.fatTargetG)) g")
            } else {
                Text("Du har ikke satt opp daglige mål ennå.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .profileCardShadow()
        .accessibilityElement(children: .contain)
    }

    private var shortcutCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                GoalOnboardingFlowView(mode: .edit).environmentObject(appState)
            } label: {
                ProfileMenuRow(icon: "target", title: "Daglige mål", value: goalSummary)
            }
            Divider().overlay(AppColors.separator)
            Button { appState.selectedTab = .search } label: {
                ProfileMenuRow(icon: "heart", title: "Favoritter", value: "\(favoriteCount) \(favoriteCount == 1 ? "matvare" : "matvarer")")
            }
            Divider().overlay(AppColors.separator)
            NavigationLink { ProfileSettingsView() } label: {
                ProfileMenuRow(icon: "gearshape", title: "Innstillinger", value: nil)
            }
        }
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        .profileCardShadow()
        .buttonStyle(.plain)
    }

    private var profileName: String {
        let name = authViewModel.currentUser?.fullName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "MatLogg-bruker" : name
    }

    private var profileInitials: String {
        guard let user = authViewModel.currentUser else { return "ML" }
        return String(user.firstName.prefix(1) + user.lastName.prefix(1)).uppercased()
    }

    private var mealCount: Int { Set(logViewModel.todaysSummary.logs.map(\.mealType)).count }

    private var todayLogLabel: String {
        if mealCount == 0 { return "Ingen måltider logget i dag" }
        return "\(mealCount) \(mealCount == 1 ? "måltid" : "måltider") logget i dag"
    }

    private var goalSummary: String? {
        guard !preferencesViewModel.safeModeHideGoals else { return "Skjult" }
        guard let goal = healthProfileViewModel.currentGoal else { return "Ikke satt" }
        return preferencesViewModel.safeModeHideCalories ? "Satt" : "\(goal.dailyCalories) kcal"
    }

    private func refreshProfileSummary() async {
        guard let userId = authViewModel.currentUser?.id else { favoriteCount = 0; return }
        await logViewModel.loadTodaysSummary(userId: userId)
        favoriteCount = await productViewModel.favoriteProducts(userId: userId).count
        await appState.refreshSyncStatus()
    }
}

private struct ProfileMetricCard: View {
    let title: String
    let value: String
    let tint: Color
    let foreground: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(AppTypography.captionEmphasis).lineLimit(2)
            Text(value).font(.system(.title, design: .rounded, weight: .heavy))
        }
        .foregroundColor(foreground)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .background(tint, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .profileCardShadow()
        .accessibilityElement(children: .combine)
    }
}

private struct GoalValueRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.deepInk)
            Spacer()
            Text(value).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    let value: String?
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.deepInk)
                .frame(width: 48, height: 48)
                .background(AppColors.mutedSurface, in: Circle())
            Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.deepInk)
            Spacer(minLength: 8)
            if let value {
                Text(value).font(AppTypography.body).foregroundColor(AppColors.textSecondary).lineLimit(1)
            }
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 78)
        .contentShape(Rectangle())
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    @EnvironmentObject private var userDataExportService: UserDataExportService
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var exportURL: URL?

    var body: some View {
        Form {
            Section("Profil og personvern") {
                NavigationLink("Personlige detaljer") { PersonalDetailsView() }
                NavigationLink("Personvern & valg") { PrivacyChoicesView() }
                NavigationLink("Fremgang") { ProgressTabView() }
            }
            Section("Preferanser") {
                Toggle("Vis målstatus på Hjem", isOn: $preferencesViewModel.showGoalStatusOnHome)
                Toggle("Haptics", isOn: $preferencesViewModel.hapticsFeedbackEnabled)
                Toggle("Lyd", isOn: $preferencesViewModel.soundFeedbackEnabled)
                Toggle("Vis datakilde", isOn: $preferencesViewModel.showNutritionSource)
                LabeledContent("Enheter", value: "Gram")
            }
            Section("Trygghet") {
                Toggle("Trygg modus", isOn: $preferencesViewModel.safeModeEnabled)
                Text("Gir en roligere visning og skjuler kalorier og mål.")
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                if !preferencesViewModel.safeModeEnabled {
                    Toggle("Skjul kalorier", isOn: $preferencesViewModel.safeModeHideCalories)
                    Toggle("Skjul mål og progresjon", isOn: $preferencesViewModel.safeModeHideGoals)
                }
            }
            Section("Data og synk") {
                LabeledContent("Status", value: syncStatusText)
                if let error = appState.lastSyncError, appState.lastSyncSucceeded == false {
                    Text(error).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                Button("Forsøk synk") { Task { await appState.triggerSync(reason: .userInitiated) } }
                Text("Du kan logge uten nett. Endringer lagres på enheten og synkroniseres når synk er tilgjengelig.")
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
            Section("Konto") {
                LabeledContent("Innlogging", value: authProviderLabel)
                if let email = authViewModel.currentUser?.email, !email.isEmpty { LabeledContent("E-post", value: email) }
                Button("Last ned data") {
                    Task {
                        guard let user = authViewModel.currentUser else { return }
                        exportURL = await userDataExportService.export(for: user)
                        showShareSheet = exportURL != nil
                    }
                }
                Button("Logg ut", role: .destructive) { authViewModel.logout() }
                Button("Slett konto", role: .destructive) { showDeleteConfirm = true }
                    .disabled(authViewModel.isDeletingAccount)
            }
            #if DEBUG
            Section("Debug") { NavigationLink("Theme Preview") { ThemePreviewView() } }
            #endif
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Innstillinger")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Slett konto?", isPresented: $showDeleteConfirm) {
            Button(authViewModel.isDeletingAccount ? "Sletter …" : "Slett", role: .destructive) {
                Task {
                    if !(await authViewModel.deleteAccount()) {
                        appState.presentError(title: "Kunne ikke slette kontoen", message: authViewModel.errorMessage)
                    }
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Lokale data slettes umiddelbart. Kontoen markeres for permanent sletting etter 30 dager. Dette kan ikke angres i appen.")
        }
        .sheet(isPresented: $showShareSheet) { if let exportURL { ShareSheet(activityItems: [exportURL]) } }
    }

    private var authProviderLabel: String { authViewModel.currentUser?.authProvider.capitalized ?? "Ukjent" }
    private var syncStatusText: String {
        if !FeatureFlags.backendSyncEnabled { return appState.pendingSyncCount == 0 ? "Lagret lokalt" : "\(appState.pendingSyncCount) venter" }
        if appState.pendingSyncCount > 0 { return "\(appState.pendingSyncCount) venter" }
        if appState.lastSyncSucceeded == true { return "Alt synket" }
        if appState.lastSyncSucceeded == false { return "Synk feilet" }
        return "Venter på synk"
    }
}

private extension View {
    func profileCardShadow() -> some View { shadow(color: Color.black.opacity(0.07), radius: 0, x: 0, y: 7) }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
