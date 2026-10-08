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
    let healthProfileViewModel: HealthProfileViewModel
    @State private var isPullRefreshing = false
    @StateObject private var goalModel: ProgressGoalViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @EnvironmentObject private var viewModel: ProgressViewModel
    private var summaries: [DailySummary] { viewModel.summaries }
    private var metrics: ProgressMetrics { viewModel.metrics }
    private var isLoading: Bool { viewModel.isLoading }

    private var today: DailySummary? { metrics.today }
    private var goal: Goal? { goalModel.goal }

    init(healthProfileViewModel: HealthProfileViewModel) {
        self.healthProfileViewModel = healthProfileViewModel
        _goalModel = StateObject(wrappedValue: ProgressGoalViewModel(health: healthProfileViewModel))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text("Utvikling")
                            .font(AppTypography.hero)
                            .foregroundColor(AppColors.deepInk)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        ActivityIndicatorSlot(isActive: viewModel.showsLoadingFeedback && !isPullRefreshing && !summaries.isEmpty,
                                              label: "Oppdaterer oversikten")
                    }

                    if let error = viewModel.errorMessage {
                        ErrorMessageView(error).font(AppTypography.caption)
                        Button("Prøv igjen") { Task { await reload() } }.frame(minHeight: 44)
                    }
                    if isLoading && summaries.isEmpty {
                        loadingState
                    } else if viewModel.errorMessage == nil && summaries.allSatisfy({ $0.logs.isEmpty }) {
                        emptyState
                    } else if !summaries.isEmpty {
                        calorieHighlights
                        weeklyCard
                        if let goal { macroCard(goal: goal) }
                    }

                    weightCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .matLoggTabBarScrollClearance()
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.actionText)
                }
            }
            .task(id: authViewModel.currentUser?.id) { await reload() }
            .refreshable {
                isPullRefreshing = true
                defer { isPullRefreshing = false }
                await reload()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Henter tallene dine …")
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var emptyState: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Label("Ingen måltider logget ennå", systemImage: "chart.bar")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.deepInk)
                Text("Når du logger mat, vises ukesoversikten her.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                Button("Gå til Hjem") { appState.selectedTab = .home }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.actionText)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calorieHighlights: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            highlightCard(
                eyebrow: "I DAG",
                value: "\(NutritionDisplay.wholeCalories(today?.totalCalories ?? 0))",
                detail: goal == nil ? "kcal" : "av \(goal?.dailyCalories ?? 0) kcal",
                fill: AppColors.surface
            )
            highlightCard(
                eyebrow: "SNITT SISTE 7 DAGER",
                value: "\(metrics.averageCalories)",
                detail: "kcal per dag",
                fill: AppColors.surface
            )
        }
    }

    private func highlightCard(eyebrow: String, value: String, detail: String, fill: Color, foreground: Color = AppColors.deepInk) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(AppTypography.captionEmphasis)
                .foregroundColor(foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundColor(foreground)
                .contentTransition(.numericText())
            Text(detail)
                .font(AppTypography.captionEmphasis)
                .foregroundColor(foreground)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(18)
        .matLoggCardSurface(fill: fill)
        .accessibilityElement(children: .combine)
    }

    private var weeklyCard: some View {
        WeeklyCaloriesCard(summaries: summaries, dailyCalories: goal?.dailyCalories)
    }

    private func macroCard(goal: Goal) -> some View {
        dashboardCard(title: "Makroer mot mål") {
            ProgressRow(label: "Protein", valueText: macroValue(today?.totalProtein ?? 0, goal.proteinTargetG), progress: ratio(today?.totalProtein ?? 0, goal.proteinTargetG), tint: AppColors.macroProteinTint)
            ProgressRow(label: "Karbohydrater", valueText: macroValue(today?.totalCarbs ?? 0, goal.carbsTargetG), progress: ratio(today?.totalCarbs ?? 0, goal.carbsTargetG), tint: AppColors.macroCarbTint)
            ProgressRow(label: "Fett", valueText: macroValue(today?.totalFat ?? 0, goal.fatTargetG), progress: ratio(today?.totalFat ?? 0, goal.fatTargetG), tint: AppColors.macroFatTint)
        }
    }

    private var weightCard: some View {
        dashboardCard(title: "Vekt") {
            WeightCardContent()
        }
    }

    private func dashboardCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.deepInk)
                    .accessibilityAddTraits(.isHeader)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func reload() async {
        let userId = authViewModel.currentUser?.id
        async let summaries: Void = viewModel.load(userId: userId)
        async let health: Void = loadHealth(userId: userId)
        _ = await (summaries, health)
    }

    private func loadHealth(userId: UUID?) async {
        guard let userId else { return }
        async let goal: Void = healthProfileViewModel.loadGoal(userId: userId)
        async let weights: Void = healthProfileViewModel.loadWeightEntries(userId: userId)
        _ = await (goal, weights)
    }

    private func ratio(_ value: Float, _ target: Float) -> Double {
        target > 0 ? Double(value / target) : 0
    }

    private func macroValue(_ value: Float, _ target: Float) -> String {
        "\(NutritionDisplay.wholeGrams(value)) / \(NutritionDisplay.wholeGrams(target)) g"
    }

    private func dayLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "I dag" : date.formatted(.dateTime.weekday(.abbreviated))
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
                    .padding(12)
                    .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
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

private struct WeeklyCaloriesCard: View {
    let summaries: [DailySummary]
    let dailyCalories: Int?
    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Kalorier gjennom uka")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.deepInk)
                    .accessibilityAddTraits(.isHeader)
            #if canImport(Charts)
            Chart(summaries, id: \.date) { summary in
                BarMark(
                    x: .value("Dag", summary.date, unit: .day),
                    y: .value("Kilokalorier", summary.totalCalories)
                )
                .foregroundStyle(AppColors.energyChart)
                .cornerRadius(6)
                if let dailyCalories {
                    RuleMark(y: .value("Mål", dailyCalories))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 140)
            .accessibilityLabel("Kalorier gjennom de siste sju dagene")
            #endif

            HStack {
                ForEach(summaries, id: \.date) { summary in
                    VStack(spacing: 4) {
                        Text("\(NutritionDisplay.wholeCalories(summary.totalCalories))")
                            .font(.caption2.weight(.semibold))
                        Text(dayLabel(summary.date))
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? "I dag"
            : date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "nb_NO")))
    }
}
