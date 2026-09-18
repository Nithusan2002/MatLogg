import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct ProgressTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel

    @State private var summaries: [DailySummary] = []
    @State private var isLoading = true
    @State private var weightText = ""
    @State private var selectedDate = Date()
    @State private var showWeightEntry = false
    @State private var showDeleteConfirm = false
    @State private var entryToDelete: WeightEntry?

    private var metrics: ProgressMetrics { ProgressMetrics(summaries: summaries) }
    private var today: DailySummary? { metrics.today }
    private var goal: Goal? { healthProfileViewModel.currentGoal }
    private var hidesCalories: Bool { preferencesViewModel.safeModeHideCalories }
    private var hidesGoals: Bool { preferencesViewModel.safeModeHideGoals }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    Text("Tallene dine")
                        .font(AppTypography.hero)
                        .foregroundColor(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)

                    if isLoading {
                        loadingState
                    } else if summaries.allSatisfy({ $0.logs.isEmpty }) {
                        emptyState
                    } else {
                        if !hidesCalories { calorieHighlights }
                        if !hidesCalories { weeklyCard }
                        if !hidesGoals, let goal { macroCard(goal: goal) }
                        mealDistributionCard
                    }

                    weightCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.action)
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .alert("Slette vektregistrering?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) { deleteSelectedWeight() }
                Button("Avbryt", role: .cancel) {}
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
                Text("Når du logger mat, vises ukesoversikt og fordeling her.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                Button("Gå til Hjem") { appState.selectedTab = .home }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.action)
                    .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var calorieHighlights: some View {
        HStack(spacing: 12) {
            highlightCard(
                eyebrow: "I DAG",
                value: "\(today?.totalCalories ?? 0)",
                detail: hidesGoals || goal == nil ? "kcal" : "av \(goal?.dailyCalories ?? 0) kcal",
                fill: AppColors.calorieBlue
            )
            highlightCard(
                eyebrow: "SNITT SISTE 7 DAGER",
                value: "\(metrics.averageCalories)",
                detail: "kcal per dag",
                fill: AppColors.surface
            )
        }
    }

    private func highlightCard(eyebrow: String, value: String, detail: String, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow)
                .font(AppTypography.captionEmphasis)
                .foregroundColor(AppColors.deepInk.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundColor(AppColors.deepInk)
                .contentTransition(.numericText())
            Text(detail)
                .font(AppTypography.captionEmphasis)
                .foregroundColor(AppColors.deepInk.opacity(0.78))
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(18)
        .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppColors.deepInk.opacity(0.06), radius: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private var weeklyCard: some View {
        dashboardCard(title: "Kalorier gjennom uka") {
            #if canImport(Charts)
            Chart(summaries, id: \.date) { summary in
                BarMark(
                    x: .value("Dag", summary.date, unit: .day),
                    y: .value("Kilokalorier", summary.totalCalories)
                )
                .foregroundStyle(Calendar.current.isDateInToday(summary.date) ? AppColors.calorieBlue : AppColors.calorieBlue.opacity(0.42))
                .cornerRadius(6)
                if let goal, !hidesGoals {
                    RuleMark(y: .value("Mål", goal.dailyCalories))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 168)
            .accessibilityLabel("Kalorier gjennom de siste sju dagene")
            #endif

            HStack {
                ForEach(summaries, id: \.date) { summary in
                    VStack(spacing: 4) {
                        Text("\(summary.totalCalories)")
                            .font(.caption2.weight(.semibold))
                        Text(dayLabel(summary.date))
                            .font(.caption2)
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func macroCard(goal: Goal) -> some View {
        dashboardCard(title: "Makroer mot mål") {
            ProgressRow(label: "Protein", valueText: macroValue(today?.totalProtein ?? 0, goal.proteinTargetG), progress: ratio(today?.totalProtein ?? 0, goal.proteinTargetG), tint: AppColors.macroProteinTint)
            ProgressRow(label: "Karbohydrater", valueText: macroValue(today?.totalCarbs ?? 0, goal.carbsTargetG), progress: ratio(today?.totalCarbs ?? 0, goal.carbsTargetG), tint: AppColors.macroCarbTint)
            ProgressRow(label: "Fett", valueText: macroValue(today?.totalFat ?? 0, goal.fatTargetG), progress: ratio(today?.totalFat ?? 0, goal.fatTargetG), tint: AppColors.macroFatTint)
        }
    }

    private var mealDistributionCard: some View {
        dashboardCard(title: "Fordeling per måltid") {
            ForEach(MealPresentation.all) { meal in
                let calories = metrics.calories(forMeal: meal.key)
                HStack {
                    Text(meal.title)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.deepInk)
                    Spacer()
                    Text(hidesCalories ? (calories > 0 ? "logget" : "ikke logget") : (calories > 0 ? "\(calories) kcal" : "ikke logget"))
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(calories > 0 ? AppColors.action : AppColors.textSecondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var weightCard: some View {
        dashboardCard(title: "Vekt") {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showWeightEntry.toggle() }
            } label: {
                Label(showWeightEntry ? "Skjul registrering" : "Loggfør vekt", systemImage: showWeightEntry ? "chevron.up" : "plus")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.action)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)

            if showWeightEntry {
                DatePicker("Dato", selection: $selectedDate, displayedComponents: .date)
                TextField("Vekt (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
                PrimaryButton(title: "Lagre", systemImage: "plus") { Task { await saveWeight() } }
            }

            if healthProfileViewModel.weightEntries.isEmpty {
                Text("Ingen vektdata ennå")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            } else {
                ForEach(healthProfileViewModel.weightEntries.suffix(3).reversed()) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.day().month(.abbreviated)))
                        Spacer()
                        Text("\(formatWeight(entry.weightKg)) kg").fontWeight(.semibold)
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.deepInk)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        entryToDelete = entry
                        showDeleteConfirm = true
                    }
                }
            }
        }
    }

    private func dashboardCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(AppTypography.title)
                .foregroundColor(AppColors.deepInk)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.separator.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: AppColors.deepInk.opacity(0.06), radius: 0, y: 7)
    }

    private func reload() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }
        isLoading = true
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var loaded: [DailySummary] = []
        for offset in (-6...0) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            loaded.append(await logViewModel.fetchSummary(userId: userId, date: date))
        }
        summaries = loaded
        await healthProfileViewModel.loadGoal(userId: userId)
        await healthProfileViewModel.loadWeightEntries(userId: userId)
        isLoading = false
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

    private func ratio(_ value: Float, _ target: Float) -> Double {
        target > 0 ? Double(value / target) : 0
    }

    private func macroValue(_ value: Float, _ target: Float) -> String {
        "\(Int(value.rounded())) / \(Int(target.rounded())) g"
    }

    private func dayLabel(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "I dag" : date.formatted(.dateTime.weekday(.abbreviated))
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

struct ProgressMetrics {
    let summaries: [DailySummary]

    var today: DailySummary? { summaries.last }
    var averageCalories: Int {
        guard !summaries.isEmpty else { return 0 }
        return Int((Double(summaries.reduce(0) { $0 + $1.totalCalories }) / Double(summaries.count)).rounded())
    }

    func calories(forMeal mealType: String) -> Int {
        today?.logs.filter { $0.mealType == mealType }.reduce(0) { $0 + $1.calories } ?? 0
    }
}
