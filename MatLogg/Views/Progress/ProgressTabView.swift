import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct ProgressTabView: View {
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    var body: some View { ProgressTabContent(healthProfileViewModel: healthProfileViewModel) }
}

private struct ProgressTabContent: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var viewModel: ProgressViewModel
    @EnvironmentObject private var hub: ProgressHubViewModel
    @EnvironmentObject private var steps: StepCountViewModel
    @EnvironmentObject private var healthWeight: HealthWeightViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsHealthSettings = false

    var body: some View {
        let stepContext = healthReadContext(for: .steps)
        let weightContext = healthReadContext(for: .weight)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if hub.owner == authViewModel.currentUser?.id {
                        if !hub.layout.visibleAreas.isEmpty {
                            periodPicker
                            dateNavigation
                        }
                        ForEach(rows) { row in
                            if row.areas == [.nutrition] {
                                NavigationLink {
                                    NutritionPeriodDetailView(model: viewModel)
                                } label: {
                                    CompactNutritionCard(model: viewModel)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("progress-hub-nutrition-open")
                            } else {
                                let isPaired = row.areas.count == 2 && !dynamicTypeSize.isAccessibilitySize
                                let layout = !isPaired
                                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                                    : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
                                layout {
                                    ForEach(row.areas) { area in
                                        metricCard(area, isPaired: isPaired)
                                            .frame(maxWidth: .infinity, alignment: .topLeading)
                                    }
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if hub.layout.visibleAreas.isEmpty { emptyHub }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .matLoggTabBarScrollClearance()
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 1)
                    .background(AppColors.background, ignoresSafeAreaEdges: .top)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: Binding(get: { hub.draft != nil }, set: { if !$0 { hub.cancelEditing() } })) {
                ProgressHubCustomizeView(model: hub)
            }
            .onReceive(healthProfileViewModel.$weightEntries) { entries in
                viewModel.updateWeights(entries, owner: authViewModel.currentUser?.id)
                if !healthProfileViewModel.isLoadingWeights, let owner = authViewModel.currentUser?.id {
                    hub.updateDefault(hasWeightHistory: !entries.isEmpty, owner: owner)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await refreshHealthReads() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                Task { await refreshHealthReads() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await refreshHealthReads() }
            }
            .task(id: PeriodReadContext(owner: authViewModel.currentUser?.id, period: viewModel.period, start: viewModel.dateRange.interval.start)) {
                await reload()
            }
            .refreshable {
                async let overview: Void = reload()
                await refreshHealthReads()
                await overview
            }
        }
        .id(authViewModel.currentUser?.id)
        .sheet(isPresented: $showsHealthSettings) {
            AppleHealthSettingsSheet()
        }
        .task(id: stepContext) {
            guard stepContext.owner == authViewModel.currentUser?.id else { return }
            await steps.update(owner: stepContext.owner, isVisible: stepContext.isVisible, range: stepContext.range)
        }
        .task(id: weightContext) {
            guard weightContext.owner == authViewModel.currentUser?.id else { return }
            await healthWeight.update(owner: weightContext.owner, isVisible: weightContext.isVisible, range: weightContext.range)
        }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            showsHealthSettings = false
        }
    }

    private func healthReadContext(for area: ProgressHubArea) -> HealthReadContext {
        let owner = authViewModel.currentUser?.id
        let isVisible = appState.selectedTab == .progress && scenePhase != .background && !showsHealthSettings
            && hub.owner == owner && hub.layout.visible.contains(area)
        return HealthReadContext(owner: owner, isVisible: isVisible, range: viewModel.dateRange.interval)
    }

    private struct HealthReadContext: Hashable {
        let owner: UUID?
        let isVisible: Bool
        let range: DateInterval
    }
    private struct PeriodReadContext: Hashable {
        let owner: UUID?
        let period: ProgressPeriod
        let start: Date
    }
    private struct Row: Identifiable {
        let areas: [ProgressHubArea]
        var id: String { areas.map(\.rawValue).joined(separator: ".") }
    }
    private var rows: [Row] {
        var groups: [[ProgressHubArea]] = []
        for area in hub.layout.visibleAreas {
            if area != .nutrition, let last = groups.last, last.count == 1, last.first != .nutrition {
                groups[groups.count - 1].append(area)
            } else { groups.append([area]) }
        }
        return groups.map { Row(areas: $0) }
    }

    private var header: some View {
        let title = Text("Utvikling")
            .font(AppTypography.hero)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("progress-hub-title")
        return VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    title.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    customizeButton.fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 4) {
                    title
                    customizeButton
                }
            }
            Text("Din oversikt, på ett sted")
                .font(AppTypography.body)
                .foregroundStyle(AppColors.textSecondary)
            if steps.snapshot(for: viewModel.dateRange.interval)?.isExampleData == true
                || healthWeight.snapshot(for: viewModel.dateRange.interval)?.isExampleData == true {
                Text("Eksempeldata")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .foregroundStyle(AppColors.deepInk)
    }

    private var customizeButton: some View {
        Button("Tilpass") { hub.beginEditing() }
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.actionText)
            .frame(minHeight: 44)
            .disabled(hub.owner == nil || hub.owner != authViewModel.currentUser?.id)
            .accessibilityIdentifier("progress-hub-customize")
    }

    private var periodPicker: some View {
        HStack(spacing: 2) {
            ForEach(ProgressPeriod.allCases) { period in
                Button { viewModel.selectPeriod(period) } label: {
                    Text(period.title).font(AppTypography.secondaryEmphasis)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(viewModel.period == period ? AppColors.onAction : AppColors.deepInk)
                        .background(viewModel.period == period ? AppColors.action : .clear,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(viewModel.period == period ? .isSelected : [])
                .accessibilityIdentifier("progress-period-" + period.rawValue)
            }
        }
        .padding(3)
        .background(AppColors.mutedSurface.opacity(0.35), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppColors.separator, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Periode for oversikten")
    }

    private var dateNavigation: some View {
        HStack(spacing: 8) {
            periodArrow("chevron.left", label: viewModel.period.previousLabel, offset: -1)
            Text(viewModel.dateRange.label)
                .font(AppTypography.sectionTitle)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("progress-period-range")
            periodArrow("chevron.right", label: viewModel.period.nextLabel, offset: 1)
        }
        .foregroundStyle(AppColors.deepInk)
    }
    private func periodArrow(_ symbol: String, label: String, offset: Int) -> some View {
        Button { viewModel.movePeriod(by: offset) } label: {
            Image(systemName: symbol).font(AppTypography.secondaryEmphasis)
                .frame(width: 44, height: 44)
                .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(offset < 0 ? "progress-period-previous" : "progress-period-next")
    }

    @ViewBuilder private func metricCard(_ area: ProgressHubArea, isPaired: Bool) -> some View {
        if area == .steps {
            NavigationLink {
                StepCountDetailView(model: steps, dateRange: viewModel.dateRange, onOpenHealthSettings: openHealthSettings)
            } label: {
                CompactStepsCard(model: steps, isPaired: isPaired)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-hub-steps-open")
        } else if area == .weight {
            let healthOverview = healthWeight.snapshot(for: viewModel.dateRange.interval)?.overview
            NavigationLink {
                WeightDetailView(healthWeight: healthWeight, dateRange: viewModel.dateRange, onOpenHealthSettings: openHealthSettings)
            } label: {
                CompactWeightCard(
                    overview: viewModel.weightOverview.showingLatest(with: healthOverview),
                    isLoading: healthProfileViewModel.isLoadingWeights || healthWeight.state == .loading,
                    isPaired: isPaired
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("progress-hub-weight-open")
        }
    }

    private var emptyHub: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Velg hva du vil se her").font(AppTypography.sectionTitle)
                Text("Du velger selv hvilke områder som vises i oversikten.")
                    .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                Button("Tilpass oversikten") { hub.beginEditing() }
                    .font(AppTypography.bodyEmphasis).foregroundStyle(AppColors.actionText)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reload() async {
        let userId = authViewModel.currentUser?.id
        hub.activate(owner: userId)
        async let summaries: Void = viewModel.load(userId: userId)
        async let health: Void = loadHealth(userId: userId)
        _ = await (summaries, health)
        guard !Task.isCancelled, userId == authViewModel.currentUser?.id, let userId else { return }
        viewModel.updateWeights(healthProfileViewModel.weightEntries, owner: userId)
        hub.updateDefault(hasWeightHistory: !healthProfileViewModel.weightEntries.isEmpty, owner: userId)
    }

    private func refreshHealthReads() async {
        async let stepRefresh: Void = steps.refresh()
        await healthWeight.refresh()
        await stepRefresh
    }

    private func openHealthSettings() {
        steps.suspend()
        healthWeight.suspend()
        showsHealthSettings = true
    }

    private func loadHealth(userId: UUID?) async {
        guard let userId else { return }
        async let goal: Void = healthProfileViewModel.loadGoal(userId: userId)
        async let weights: Void = healthProfileViewModel.loadWeightEntries(userId: userId)
        _ = await (goal, weights)
    }
}

private struct WeightDetailView: View {
    @EnvironmentObject private var health: HealthProfileViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @ObservedObject var healthWeight: HealthWeightViewModel
    let dateRange: ProgressDateRange
    let onOpenHealthSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HealthWeightCardContent(model: healthWeight, dateRange: dateRange, onOpenHealthSettings: onOpenHealthSettings)
                CardContainer {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Registrert i MatLogg")
                            .font(AppTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        WeightCardContent()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Vekt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            if let owner = auth.currentUser?.id { await health.loadWeightEntries(userId: owner) }
        }
        .task { await healthWeight.refresh() }
        .refreshable { await healthWeight.refresh() }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }.foregroundStyle(AppColors.actionText)
            }
        }
    }
}

private struct WeightCardContent: View {
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel

    var body: some View {
        Group {
            if healthProfileViewModel.isLoadingWeights {
                ProgressView("Henter vekthistorikk …")
            }
            if !healthProfileViewModel.isLoadingWeights || !healthProfileViewModel.weightEntries.isEmpty {
                WeightEntryContent()
            }
        }
    }
}

private struct WeightEntryContent: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var showWeightEntry = false

    var body: some View {
        Group {
            if let latest = healthProfileViewModel.weightEntries.last {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Siste registrering")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(formatWeight(latest.weightKg)) kg")
                        .font(AppTypography.heroValue)
                        .foregroundColor(AppColors.deepInk)
                    Text("Registrert \(weightDate(latest.date))")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ingen vekt registrert")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.deepInk)
                    Text("Vektregistrering er valgfritt. Du kan skjule kortet under Tilpass.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Divider().overlay(AppColors.separator)
            Button {
                showWeightEntry.toggle()
            } label: {
                Label(showWeightEntry ? "Skjul registrering" : "Registrer vekt", systemImage: showWeightEntry ? "chevron.up" : "plus")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.actionText)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showWeightEntry {
                Text("Ny vektregistrering")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.ink)
                    .accessibilityAddTraits(.isHeader)
                DatePicker("Dato", selection: $selectedDate, displayedComponents: .date)
                Text("Vekt (kg)")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.deepInk)
                TextField("Vekt (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                    .matLoggInputStyle()
                PrimaryButton(title: "Lagre", systemImage: "plus") { Task { await saveWeight() } }
            }

            if !healthProfileViewModel.weightEntries.isEmpty {
                Divider()
                if healthProfileViewModel.weightEntries.count > 1 {
                    Text("Tidligere registreringer")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                    WeightHistoryRows(entries: Array(healthProfileViewModel.weightEntries.suffix(4).reversed().dropFirst()))
                }
                NavigationLink {
                    WeightHistoryView()
                } label: {
                    Label("Se alle registreringer", systemImage: "chevron.right")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.actionText)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }
        }
    }

    private func saveWeight() async {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(normalized), weight > 0,
              let userId = authViewModel.currentUser?.id else { return }
        if await healthProfileViewModel.saveWeight(date: selectedDate, weightKg: weight, userId: userId) {
            weightText = ""
            showWeightEntry = false
            await appState.refreshSyncStatus()
        } else {
            appState.errorMessage = healthProfileViewModel.errorMessage
        }
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", locale: Locale(identifier: "nb_NO"), value)
    }

    private func weightDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO")))
    }
}

private struct WeightHistoryView: View {
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if healthProfileViewModel.weightEntries.isEmpty {
                    Text("Ingen vekt registrert")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                } else {
                    WeightHistoryRows(entries: Array(healthProfileViewModel.weightEntries.reversed()))
                }
            }
            .padding(20)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Vekthistorikk")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WeightHistoryRows: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    let entries: [WeightEntry]
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: WeightEntry?

    var body: some View {
        Group {
            ForEach(entries) { entry in
                HStack(spacing: 12) {
                    let layout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(spacing: 12))
                    layout {
                        Text(weightDate(entry.date))
                        if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                        Text("\(formatWeight(entry.weightKg)) kg").fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    Button(role: .destructive) {
                        entryToDelete = entry
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(AppColors.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Slett \(formatWeight(entry.weightKg)) kg registrert \(weightDate(entry.date))")
                }
                .font(AppTypography.body)
                .foregroundColor(AppColors.deepInk)
            }
        }
        .alert("Slette vektregistrering?", isPresented: $showDeleteConfirm) {
            Button("Slett", role: .destructive) { deleteSelectedWeight() }
            Button("Avbryt", role: .cancel) {}
        } message: {
            if let entryToDelete {
                Text("\(formatWeight(entryToDelete.weightKg)) kg registrert \(weightDate(entryToDelete.date)).")
            }
        }
    }

    private func deleteSelectedWeight() {
        guard let entryToDelete, let userId = authViewModel.currentUser?.id else { return }
        Task {
            if await healthProfileViewModel.deleteWeight(entryToDelete, userId: userId) {
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = healthProfileViewModel.errorMessage
            }
        }
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", locale: Locale(identifier: "nb_NO"), value)
    }

    private func weightDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO")))
    }
}

struct ProgressMetrics {
    let summaries: [DailySummary]
    let today: DailySummary?
    let averageCalories: Int

    init(summaries: [DailySummary]) {
        self.summaries = summaries
        today = summaries.last
        if summaries.isEmpty {
            averageCalories = 0
        } else {
            averageCalories = NutritionDisplay.wholeCalories(summaries.reduce(0) { $0 + $1.totalCalories } / Float(summaries.count))
        }
    }
}
