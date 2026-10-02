import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @EnvironmentObject private var demoMode: DemoMode
    @State private var confirmDemoReset = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Profil").font(AppTypography.hero).foregroundColor(AppColors.deepInk)
                    profileHeader
                    dailyGoalCard
                    shortcutCard
                    storageSummary
                    #if DEBUG
                    demoControls
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .matLoggTabBarScrollClearance()
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.action)
            .toolbar(.hidden, for: .navigationBar)
            .task { await appState.refreshSyncStatus() }
        }
    }

    private var demoControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Demomodus", isOn: Binding(get: { demoMode.isDemo }, set: { enabled in
                Task { await demoMode.selectDemo(enabled) }
            }))
            .accessibilityIdentifier("profile-demo-mode")
            Text("Fiktive data i separat lokal lagring. Dine vanlige data beholdes.")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.textSecondary)
            if demoMode.isDemo {
                Button("Tilbakestill demodata") { confirmDemoReset = true }
            }
            if demoMode.isLoading { ProgressView("Klargjør demodata …") }
        }
        .padding(20)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
        .disabled(demoMode.isLoading)
        .confirmationDialog("Tilbakestille demodata?", isPresented: $confirmDemoReset, titleVisibility: .visible) {
            Button("Tilbakestill", role: .destructive) { Task { await demoMode.selectDemo(true, reset: true) } }
        } message: { Text("Endringer i demoen fjernes. Vanlige data beholdes.") }
    }

    private var profileHeader: some View {
        NavigationLink {
            PersonalDetailsView().environmentObject(appState)
        } label: {
            HStack(spacing: 18) {
                Text(profileInitials)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundColor(AppColors.background)
                    .frame(width: 56, height: 56)
                    .background(AppColors.deepInk, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileName)
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.deepInk)
                        .lineLimit(2)
                    Text("Personlige detaljer")
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
            .matLoggCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-personal-details")
        .accessibilityHint("Åpner personlige detaljer")
    }

    private var dailyGoalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Daglige mål").font(AppTypography.title).foregroundColor(AppColors.deepInk)
            if let goal = healthProfileViewModel.currentGoal {
                GoalValueRow(label: "Kalorier", value: "\(goal.dailyCalories) kcal")
                GoalValueRow(label: "Protein", value: "\(goal.proteinTargetG.formatted(.number.precision(.fractionLength(0...1)))) g")
                GoalValueRow(label: "Karbohydrater", value: "\(goal.carbsTargetG.formatted(.number.precision(.fractionLength(0...1)))) g")
                GoalValueRow(label: "Fett", value: "\(goal.fatTargetG.formatted(.number.precision(.fractionLength(0...1)))) g")
            } else {
                Text("Du kan logge mat uten mål.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            NavigationLink { DailyGoalsView() } label: {
                Label(healthProfileViewModel.currentGoal == nil ? "Sett opp mål" : "Endre mål", systemImage: "pencil")
                    .font(AppTypography.bodyEmphasis)
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("profile-edit-goals")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .matLoggCardSurface()
        .accessibilityElement(children: .contain)
    }

    private var shortcutCard: some View {
        VStack(spacing: 0) {
            NavigationLink { ProfileFavoritesView() } label: {
                ProfileMenuRow(icon: "heart", title: "Favoritter", value: nil)
            }
            Divider().overlay(AppColors.separator)
            if FeatureFlags.healthIntegrationEnabled {
                NavigationLink { HealthIntegrationView() } label: {
                    ProfileMenuRow(icon: "heart.text.clipboard", title: "Apple Helse", value: nil)
                }
                .accessibilityIdentifier("profile-apple-health")
                Divider().overlay(AppColors.separator)
            }
            NavigationLink { ProfileSettingsView() } label: {
                ProfileMenuRow(icon: "gearshape", title: "Innstillinger", value: nil)
            }
        }
        .matLoggCardSurface()
        .buttonStyle(.plain)
        .accessibilityIdentifier("profile-shortcuts")
    }

    private var profileName: String {
        let localName = healthProfileViewModel.personalDetails.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !localName.isEmpty { return localName }
        if authViewModel.isLocalMode { return "På denne iPhonen" }
        let name = authViewModel.currentUser?.fullName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "MatLogg-bruker" : name
    }

    private var profileInitials: String {
        let localName = healthProfileViewModel.personalDetails.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let name = localName.isEmpty ? (authViewModel.currentUser?.fullName ?? "") : localName
        let parts = name.split(whereSeparator: { $0.isWhitespace })
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        return initials.isEmpty ? "ML" : initials
    }

    private var storageSummary: some View {
        Label(appState.isSyncAvailable ? "Endringer lagres først på denne iPhonen" : "Data lagres på denne iPhonen", systemImage: "externaldrive")
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                Text(value).font(AppTypography.body).foregroundColor(AppColors.textSecondary)
            }
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 78)
        .contentShape(Rectangle())
    }
}

private struct ProfileSettingsView: View {
    @EnvironmentObject private var demoMode: DemoMode
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    @EnvironmentObject private var exportViewModel: ProfileExportViewModel
    @State private var showDeleteConfirm = false
    @State private var showRemoveLocalConfirm = false

    var body: some View {
        Form {
            Section("Personvern") {
                NavigationLink("Personvern og valg") { PrivacyChoicesView() }
            }
            .listRowBackground(AppColors.surface)
            Section("Visning og tilbakemelding") {
                Toggle("Vis målstatus på Hjem", isOn: $preferencesViewModel.showGoalStatusOnHome)
                Toggle("Vibrasjon ved trykk", isOn: $preferencesViewModel.hapticsFeedbackEnabled)
                Toggle("Lyd", isOn: $preferencesViewModel.soundFeedbackEnabled)
                Toggle("Vis hvor næringstallene kommer fra", isOn: $preferencesViewModel.showNutritionSource)
                LabeledContent("Matmengder", value: "Gram og milliliter")
            }
            .listRowBackground(AppColors.surface)
            Section("Data og lagring") {
                LabeledContent("Status", value: syncStatusText)
                if appState.quarantinedSyncCount > 0 {
                    Label(
                        "\(appState.quarantinedSyncCount) eldre endring(er) er lagret på denne iPhonen. De kan ikke lastes opp fordi vi ikke kan bekrefte hvilken konto de tilhører.",
                        systemImage: "lock.trianglebadge.exclamationmark"
                    )
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                }
                if let lastSyncAt = appState.lastSyncAt, appState.isSyncAvailable {
                    LabeledContent("Siste forsøk") {
                        Text(lastSyncAt, format: .dateTime.day().month().hour().minute())
                    }
                }
                if let nextRetryAt = appState.syncQueueStatus.nextRetryAt,
                   appState.failedSyncCount == 0,
                   appState.isSyncAvailable {
                    HStack {
                        Text("Neste automatiske forsøk")
                        Spacer()
                        Text(nextRetryAt, style: .relative)
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                }

                ForEach(appState.syncFailures) { failure in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(syncTypeLabel(failure.type))
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.deepInk)
                        Text(failure.message)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Button("Prøv denne på nytt") {
                            Task { await appState.retryFailedEvent(failure.id) }
                        }
                        .disabled(appState.isSyncing || appState.networkAvailability == .offline)
                    }
                    .accessibilityElement(children: .contain)
                }

                if appState.isSyncAvailable {
                    Button(appState.isSyncing ? "Synkroniserer …" : "Synkroniser ventende endringer") {
                        Task { await appState.triggerSync(reason: .userInitiated) }
                    }
                    .disabled(
                        appState.isSyncing
                            || appState.networkAvailability == .offline
                            || appState.pendingSyncCount + appState.inFlightSyncCount == 0
                    )
                }

                if appState.isSyncAvailable {
                    Text(syncExplanationText)
                        .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                Button(exportViewModel.isExporting ? "Klargjør eksport …" : "Last ned data") {
                    Task { await exportViewModel.export(user: authViewModel.currentUser) }
                }
                .disabled(exportViewModel.isExporting)
                if let error = exportViewModel.errorMessage {
                    Text(error).font(AppTypography.caption).foregroundStyle(AppColors.ink)
                }
                DisclosureGroup("Hva følger med?") {
                    Text("Filen inneholder matlogg, vann, lagrede måltider, daglige mål, vekt registrert i MatLogg, personlige detaljer og favoritter fra denne iPhonen. Filformatet er JSON. Filen kan ikke brukes til å gjenopprette data i appen.")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .listRowBackground(AppColors.surface)
            Section("Konto") {
                if demoMode.isDemo {
                    LabeledContent("Status", value: "Demomodus – fiktiv lokal profil")
                } else if authViewModel.isLocalMode {
                    Text("Konto er valgfritt. Innlogging gir foreløpig ikke sikkerhetskopi eller synk mellom enheter.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                    NavigationLink("Logg inn eller opprett konto") { LoginView() }
                } else {
                    LabeledContent("Innlogging", value: authProviderLabel)
                    if let email = authViewModel.currentUser?.email, !email.isEmpty { LabeledContent("E-post", value: email) }
                    Button("Logg ut", role: .destructive) { authViewModel.logout() }
                    Button("Fjern data fra denne iPhonen", role: .destructive) { showRemoveLocalConfirm = true }
                    Button("Slett konto", role: .destructive) { showDeleteConfirm = true }
                        .disabled(authViewModel.isDeletingAccount)
                }
            }
            .listRowBackground(AppColors.surface)
            #if DEBUG
            Section("Debug") { NavigationLink("Theme Preview") { ThemePreviewView() } }
                .listRowBackground(AppColors.surface)
            #endif
        }
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .toolbar(.visible, for: .navigationBar)
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
            Text("Lokale data slettes umiddelbart. Kontoen markeres for permanent sletting etter 30 dager. Dette kan ikke angres i appen. Data som allerede er delt med Apple Helse beholdes. Slett dem under Profil → Apple Helse før kontosletting, eller i Helse-appen.")
        }
        .alert("Fjern data fra denne iPhonen?", isPresented: $showRemoveLocalConfirm) {
            Button("Fjern og logg ut", role: .destructive) {
                Task {
                    if !(await authViewModel.removeAccountDataFromDevice()) {
                        appState.presentError(title: "Kunne ikke fjerne data", message: authViewModel.errorMessage)
                    }
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Dataene fjernes bare fra denne iPhonen. Du kan ikke hente dem tilbake fra kontoen din ennå. Data delt med Apple Helse beholdes og må slettes separat i Helse-appen eller under Profil → Apple Helse før du fjerner profilen.")
        }
        .sheet(item: $exportViewModel.document, onDismiss: { exportViewModel.clearDocument() }) { document in
            ShareSheet(activityItems: [document.url])
        }
    }

    private var authProviderLabel: String {
        switch authViewModel.currentUser?.authProvider {
        case "apple": return "Apple"
        case "email": return "E-post"
        case "debug": return "Utvikling"
        default: return "Ukjent"
        }
    }
    private var syncStatusText: String {
        if !appState.isSyncAvailable { return "Lagret bare på denne enheten" }
        if appState.isSyncing || appState.inFlightSyncCount > 0 { return "Synkroniserer" }
        if appState.failedSyncCount > 0 { return "\(appState.failedSyncCount) krever handling" }
        if appState.networkAvailability == .offline, appState.unsyncedSyncCount > 0 { return "Offline – lagret på enheten" }
        if appState.pendingSyncCount > 0 { return "\(appState.pendingSyncCount) venter på synk" }
        if appState.lastSyncSucceeded == true { return "Alle endringer fra denne enheten er synkronisert" }
        if appState.lastSyncSucceeded == false { return "Synk feilet" }
        return "Ingen endringer venter på synk"
    }

    private var syncExplanationText: String {
        if !appState.isSyncAvailable {
            return "Du kan logge uten nett. Endringene lagres bare på denne iPhonen. Opplasting er ikke tilgjengelig ennå."
        }
        if appState.networkAvailability == .offline {
            return "Du er offline. Endringene er lagret på enheten; synk forsøkes neste gang appen er aktiv med nett."
        }
        return "Endringer lagres først på enheten. Synk forsøkes når appen er aktiv og nett er tilgjengelig."
    }

    private func syncTypeLabel(_ type: String) -> String {
        switch type {
        case let value where value.hasPrefix("log."): return "Matlogg"
        case "goal.set": return "Daglig mål"
        case let value where value.hasPrefix("weight."): return "Vektregistrering"
        case let value where value.hasPrefix("favorite."): return "Favoritt"
        case let value where value.hasPrefix("saved_meal."): return "Lagret måltid"
        case "product.upsert": return "Brukeropprettet produkt"
        default: return "Lokal endring"
        }
    }
}


struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
