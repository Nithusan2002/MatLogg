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

    private var shortcutCard: some View {
        VStack(spacing: 0) {
            NavigationLink { DailyGoalsView() } label: {
                ProfileMenuRow(
                    icon: "target",
                    title: "Daglige mål",
                    subtitle: healthProfileViewModel.currentGoal.map {
                        "\($0.dailyCalories.formatted(.number.locale(Locale(identifier: "nb_NO")))) kcal per dag"
                    } ?? "Valgfritt · Sett opp mål"
                )
            }
            .accessibilityIdentifier("profile-edit-goals")
            .accessibilityHint("Åpner redigering av daglige mål")
            Divider().overlay(AppColors.separator)
            NavigationLink { ProfileFavoritesView() } label: {
                ProfileMenuRow(icon: "heart", title: "Favoritter")
            }
            Divider().overlay(AppColors.separator)
            NavigationLink { ProfileSettingsView() } label: {
                ProfileMenuRow(icon: "gearshape", title: "Innstillinger")
            }
            Divider().overlay(AppColors.separator)
            NavigationLink { HelpSupportView() } label: {
                ProfileMenuRow(icon: "questionmark.circle", title: "Hjelp og støtte")
            }
            .accessibilityIdentifier("profile-help-support")
            .accessibilityHint("Åpner vanlige spørsmål og kontaktinformasjon")
        }
        .matLoggCardSurface()
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
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

private struct ProfileMenuRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundColor(AppColors.deepInk)
                .frame(width: 48, height: 48)
                .background(AppColors.mutedSurface, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.deepInk)
                if let subtitle {
                    Text(subtitle)
                        .font(AppTypography.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minHeight: 78)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
    @State private var showAppleEmailInformation = false

    var body: some View {
        Form {
            Section("Personvern") {
                NavigationLink("Personvern og valg") { PrivacyChoicesView() }
            }
            .listRowBackground(AppColors.surface)
            Section {
                Picker(selection: $preferencesViewModel.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                } label: {
                    Label("Utseende", systemImage: "circle.lefthalf.filled")
                        .foregroundStyle(AppColors.ink)
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("profile-appearance")
            }
            .listRowBackground(AppColors.surface)
            Section("Visning og tilbakemelding") {
                Toggle("Vis energi og mål på Hjem", isOn: $preferencesViewModel.showGoalStatusOnHome)
                Toggle("Vibrasjon ved trykk", isOn: $preferencesViewModel.hapticsFeedbackEnabled)
                Toggle("Lyd", isOn: $preferencesViewModel.soundFeedbackEnabled)
                Toggle("Vis hvor næringstallene kommer fra", isOn: $preferencesViewModel.showNutritionSource)
                LabeledContent("Matmengder", value: "Gram og milliliter")
            }
            .listRowBackground(AppColors.surface)
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label(appState.isSyncAvailable ? "Lagring og synk" : "Lagret på denne iPhonen", systemImage: "iphone")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.ink)
                    if appState.isSyncAvailable {
                        Text(syncStatusText)
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        Text("Tilgjengelig uten nett")
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                if appState.isSyncAvailable && appState.quarantinedSyncCount > 0 {
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

                ForEach(appState.isSyncAvailable ? appState.syncFailures : []) { failure in
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

                Button {
                    Task { await exportViewModel.export(user: authViewModel.currentUser) }
                } label: {
                    HStack(spacing: 12) {
                        Label(exportViewModel.isExporting ? "Klargjør eksport …" : "Eksporter data", systemImage: "square.and.arrow.up")
                        Spacer(minLength: 0)
                        if exportViewModel.isExporting {
                            ProgressView()
                                .accessibilityHidden(true)
                        }
                    }
                    .foregroundStyle(AppColors.actionText)
                    .frame(minHeight: 44)
                }
                .disabled(exportViewModel.isExporting)
                if let error = exportViewModel.errorMessage {
                    ErrorMessageView(error).font(AppTypography.caption)
                }
                DisclosureGroup("Hva følger med?") {
                    Text("En JSON-fil med matlogg, vann, lagrede måltider, daglige mål, vekthistorikk, personlige detaljer og favoritter for den aktive profilen.")
                        .font(AppTypography.secondary)
                        .foregroundStyle(AppColors.textSecondary)
                }
            } header: {
                Text("Data og lagring")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if appState.isSyncAvailable {
                        Text(syncExplanationText)
                    } else {
                        Text("Ingen skybackup. Data kan gå tapt hvis du sletter appen eller mister telefonen.")
                    }
                    Text("Eksporten er en kopi for innsyn og deling. Den kan ikke importeres tilbake i MatLogg.")
                }
            }
            .listRowBackground(AppColors.surface)
            Section {
                if demoMode.isDemo {
                    Label("Demomodus – fiktiv lokal profil", systemImage: "person.crop.circle")
                } else if authViewModel.isLocalMode {
                    NavigationLink("Logg inn eller opprett konto") { LoginView() }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Logget inn med \(authProviderLabel)", systemImage: authViewModel.currentUser?.authProvider == "apple" ? "apple.logo" : "person.crop.circle")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.ink)
                        if let email = authViewModel.currentUser?.email, !email.isEmpty {
                            Text(email)
                                .font(AppTypography.secondary)
                                .foregroundStyle(AppColors.textSecondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("E-post: \(email)")
                            if authViewModel.currentUser?.authProvider == "apple",
                               email.lowercased().hasSuffix("@privaterelay.appleid.com") {
                                HStack(alignment: .center, spacing: 8) {
                                    Text("Privat e-postadresse fra Apple")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                    Button {
                                        showAppleEmailInformation = true
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .frame(minWidth: 44, minHeight: 44)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(AppColors.actionText)
                                    .accessibilityLabel("Om privat e-postadresse fra Apple")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    Button { authViewModel.logout() } label: {
                        Label("Logg ut", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(AppColors.ink)
                            .frame(minHeight: 44)
                    }
                }
            } header: {
                Text("Konto")
            } footer: {
                if !demoMode.isDemo {
                    Text(authViewModel.isLocalMode
                         ? "Konto er valgfritt. Innlogging gir foreløpig ikke skybackup eller synk mellom enheter."
                         : "Matloggene lagres bare på denne iPhonen. Kontoen gir ikke skybackup.")
                }
            }
            .listRowBackground(AppColors.surface)
            if !demoMode.isDemo && !authViewModel.isLocalMode {
                Section("Sletting") {
                    Button("Fjern lokale data", role: .destructive) { showRemoveLocalConfirm = true }
                    if authViewModel.isDeletingAccount { ProgressView("Sletter konto …") }
                    Button("Slett konto", role: .destructive) { showDeleteConfirm = true }
                        .disabled(authViewModel.isDeletingAccount)
                }
                .listRowBackground(AppColors.surface)
            }
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
        .alert("Privat e-postadresse fra Apple", isPresented: $showAppleEmailInformation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Du har valgt Skjul e-post hos Apple. Denne adressen videresender e-post til adressen som er knyttet til Apple-kontoen din.")
        }
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
            Text("Dataene fjernes bare fra denne iPhonen. Du kan ikke hente dem tilbake fra kontoen din ennå.")
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
        if !appState.isSyncAvailable { return "Lagret på denne enheten" }
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
