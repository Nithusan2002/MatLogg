import SwiftUI
import AVFoundation
import UIKit

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel

    var body: some View {
        HomeNavigationContent(appState: appState, logViewModel: logViewModel,
            authViewModel: authViewModel, savedMealsViewModel: savedMealsViewModel)
    }
}

private struct HomeNavigationContent: View {
    let appState: AppState
    let logViewModel: LogViewModel
    let authViewModel: AuthViewModel
    let savedMealsViewModel: SavedMealsViewModel
    @StateObject private var navigation: HomeNavigationViewModel
    @State private var showScanCamera = false
    @State private var showRawMaterials = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var isUndoingSavedMeal = false
    @State private var showAddActions = false
    @State private var previousTab: AppTab = .home
    @State private var isTabEditing = false
    @State private var tabBarScrollMargin = MatLoggTabBar.defaultScrollContentBottomMargin

    init(appState: AppState, logViewModel: LogViewModel, authViewModel: AuthViewModel,
         savedMealsViewModel: SavedMealsViewModel) {
        self.appState = appState
        self.logViewModel = logViewModel
        self.authViewModel = authViewModel
        self.savedMealsViewModel = savedMealsViewModel
        _navigation = StateObject(wrappedValue: HomeNavigationViewModel(appState: appState,
            auth: authViewModel, savedMeals: savedMealsViewModel))
    }

    var body: some View {
        let timing = PerformanceSignposts.begin("UI.TabBody")
        defer { PerformanceSignposts.end(timing) }
        // The custom bar owns labels and accessibility; avoid resolving icons
        // for the hidden system tab bar while retaining TabView state.
        return TabView(selection: tabSelection) {
            HomeTabView(
                onOpenQuickLog: { showAddActions = true },
                onLogComplete: { payload in
                    Task { await loadTodaysSummary() }
                    receiptPayload = payload
                }
            )
                .tabItem { EmptyView() }
                .tag(AppTab.home)
                .matLoggSystemTabBarHidden()

            SearchHubView(
                onScan: { showScanCamera = true },
                onLogComplete: { payload in
                    receiptPayload = payload
                    Task { await loadTodaysSummary() }
                },
                onSavedMealLogComplete: {
                    Task {
                        await loadTodaysSummary()
                        await appState.refreshSyncStatus()
                    }
                }
            )
                .tabItem { EmptyView() }
                .tag(AppTab.search)
                .matLoggSystemTabBarHidden()

            Color.clear
                .tabItem { EmptyView() }
                .tag(AppTab.add)
                .matLoggSystemTabBarHidden()

            ProgressTabView()
                .tabItem { EmptyView() }
                .tag(AppTab.progress)
                .matLoggSystemTabBarHidden()

            ProfileView()
                .tabItem { EmptyView() }
                .tag(AppTab.profile)
                .matLoggSystemTabBarHidden()
        }
        .onPreferenceChange(MatLoggTabBarEditingKey.self) { isTabEditing = $0 }
        .environment(\.matLoggTabBarScrollMargin, isTabEditing ? 0 : tabBarScrollMargin)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isTabEditing {
                MatLoggTabBar(selection: tabSelection)
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        tabBarScrollMargin = max(
                            MatLoggTabBar.defaultScrollContentBottomMargin,
                            height + MatLoggTabBar.scrollContentSpacing
                        )
                    }
            }
        }
        .environmentObject(appState)
        .overlay(alignment: .bottom) {
            if let payload = receiptPayload {
                LogToastView(
                    payload: payload,
                    isUndoing: isUndoingReceipt,
                    onUndo: { undoLogging(payload) },
                    onDismiss: { dismissReceipt() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, tabBarScrollMargin)
                .transition(.logToast)
            } else if let receipt = navigation.savedMealReceipt {
                SavedMealToastView(
                    receipt: receipt,
                    isUndoing: isUndoingSavedMeal,
                    onUndo: { undoSavedMeal() },
                    onDismiss: { savedMealsViewModel.dismissReceipt() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, tabBarScrollMargin)
                .transition(.logToast)
                .task(id: receipt.logIDs) {
                    let seconds: UInt64 = UIAccessibility.isVoiceOverRunning ? 8 : 4
                    try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                    guard !Task.isCancelled,
                          savedMealsViewModel.receipt?.logIDs == receipt.logIDs else { return }
                    savedMealsViewModel.dismissReceipt()
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { navigation.isOnboarding },
            set: { _ in }
        )) {
            OnboardingView { payload in
                receiptPayload = payload
                authViewModel.finishOnboarding()
            }
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showScanCamera) {
            CameraView(
                onLogComplete: { _ in
                    Task {
                        await loadTodaysSummary()
                    }
                },
                onSearch: { showRawMaterials = true }
            )
        }
        .fullScreenCover(isPresented: $showRawMaterials) {
            RawMaterialsSearchView { payload in
                showRawMaterials = false
                receiptPayload = payload
                Task { await loadTodaysSummary() }
            }
                .environmentObject(appState)
        }
        .onAppear {
            Task {
                await loadTodaysSummary()
            }
        }
        .onChange(of: navigation.selectedTab) { _, newValue in
            if newValue != .add { previousTab = newValue }
        }
        .sheet(isPresented: $showAddActions) {
            LoggingFlowView(
                onLogComplete: { payload in
                    receiptPayload = payload
                    Task { await loadTodaysSummary() }
                },
                onSavedMealLogComplete: {
                    Task {
                        await loadTodaysSummary()
                        await appState.refreshSyncStatus()
                    }
                }
            )
            .presentationDetents([.fraction(0.66), .large])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(36)
        }
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { navigation.selectedTab },
            set: { newValue in
                if newValue == .add {
                    showAddActions = true
                    appState.selectedTab = previousTab
                } else {
                    appState.selectedTab = newValue
                    previousTab = newValue
                }
            }
        )
    }

    private func loadTodaysSummary() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        await logViewModel.loadTodaysSummary(userId: userId)
    }

    private func dismissReceipt() {
        if UIAccessibility.isReduceMotionEnabled {
            receiptPayload = nil
        } else {
            withAnimation(.smooth(duration: 0.32)) { receiptPayload = nil }
        }
    }

    private func undoLogging(_ payload: ReceiptPayload) {
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id,
              payload.ownerID == nil || payload.ownerID == userId else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate,
                logID: payload.logID
            )
            if succeeded {
                dismissReceipt()
                await loadTodaysSummary()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage ?? "Kunne ikke angre loggingen."
            }
            isUndoingReceipt = false
        }
    }

    private func undoSavedMeal() {
        guard !isUndoingSavedMeal else { return }
        isUndoingSavedMeal = true
        Task {
            if await savedMealsViewModel.undo() {
                await loadTodaysSummary()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = savedMealsViewModel.errorMessage ?? "Kunne ikke angre måltidet."
            }
            isUndoingSavedMeal = false
        }
    }
}

private extension View {
    @ViewBuilder
    func matLoggSystemTabBarHidden() -> some View {
        if #available(iOS 18.0, *) {
            toolbarVisibility(.hidden, for: .tabBar)
        } else {
            toolbar(.hidden, for: .tabBar)
        }
    }
}

struct HomeTabView: View {
    @Environment(\.foodLogRepository) private var repository
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel
    @EnvironmentObject private var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject private var preferencesViewModel: PreferencesViewModel
    let onOpenQuickLog: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        if let repository {
            HomeTabContent(repository: repository, appState: appState, logViewModel: logViewModel,
                authViewModel: authViewModel, savedMealsViewModel: savedMealsViewModel,
                healthProfileViewModel: healthProfileViewModel, preferencesViewModel: preferencesViewModel,
                onOpenQuickLog: onOpenQuickLog, onLogComplete: onLogComplete)
        } else {
            ContentUnavailableView("Oversikt er utilgjengelig", systemImage: "fork.knife")
        }
    }
}

private struct HomeTabContent: View {
    let savedMealsViewModel: SavedMealsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var mealReuseViewModel: MealReuseViewModel
    let appState: AppState
    let logViewModel: LogViewModel
    let healthProfileViewModel: HealthProfileViewModel
    let authViewModel: AuthViewModel
    let preferencesViewModel: PreferencesViewModel
    let onOpenQuickLog: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    @State private var isPullRefreshing = false
    @StateObject private var overviewModel: HomeOverviewViewModel
    private var selectedSummary: DailySummary? { overviewModel.overview.summary }
    private var productNames: [UUID: String] { overviewModel.overview.productNames }
    @State private var selectedProduct: Product?
    @State private var selectedMealForLog: MealPresentation?
    @State private var showDailyLog = false
    @State private var editingLog: FoodLog?
    private var isSummaryLoading: Bool { overviewModel.isLoading }

    init(repository: any FoodLogRepository, appState: AppState, logViewModel: LogViewModel,
         authViewModel: AuthViewModel, savedMealsViewModel: SavedMealsViewModel,
         healthProfileViewModel: HealthProfileViewModel, preferencesViewModel: PreferencesViewModel,
         onOpenQuickLog: @escaping () -> Void, onLogComplete: @escaping (ReceiptPayload) -> Void) {
        self.appState = appState
        self.logViewModel = logViewModel
        self.authViewModel = authViewModel
        self.savedMealsViewModel = savedMealsViewModel
        self.healthProfileViewModel = healthProfileViewModel
        self.preferencesViewModel = preferencesViewModel
        self.onOpenQuickLog = onOpenQuickLog
        self.onLogComplete = onLogComplete
        _overviewModel = StateObject(wrappedValue: HomeOverviewViewModel(repository: repository,
            appState: appState, auth: authViewModel, logs: logViewModel, savedMeals: savedMealsViewModel,
            health: healthProfileViewModel, preferences: preferencesViewModel))
    }

    var body: some View {
        let timing = PerformanceSignposts.begin("UI.HomeBody")
        defer { PerformanceSignposts.end(timing) }
        let logsByMeal = overviewModel.overview.logsByMeal

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DayNavigationBar(selection: selectedDateBinding)

                    HomeSyncBanner()

                    if !preferencesViewModel.showGoalStatusOnHome, let error = overviewModel.errorMessage {
                        ErrorMessageView(error).font(AppTypography.caption)
                        Button("Prøv igjen") { Task { await refreshSummaries() } }
                            .frame(minHeight: 44)
                    }
                    if isSummaryLoading && !isPullRefreshing && (selectedSummary != nil || !preferencesViewModel.showGoalStatusOnHome) {
                        ProgressView("Henter oversikt …")
                    }


                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                homeHeadingText(at: context.date).fixedSize()
                                Spacer(minLength: 0)
                                loggingStreakBadge
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                homeHeadingText(at: context.date)
                                loggingStreakBadge
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        if preferencesViewModel.showGoalStatusOnHome {
                            if isSummaryLoading && selectedSummary == nil {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Henter oversikt …")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.energyTextSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                                .accessibilityElement(children: .combine)
                            } else if let summary = selectedSummary {
                                StatusSummaryContent(
                                    summary: summary,
                                    goal: healthProfileViewModel.currentGoal
                                )
                            } else if overviewModel.errorMessage == nil {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Matloggen din er klar", systemImage: "chart.bar")
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                    Text("Logg mat uten dagsmål. Du kan sette opp mål senere under Profil → Daglige mål.")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.energyTextSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if let error = overviewModel.errorMessage {
                                ErrorMessageView(error)
                                    .font(AppTypography.caption)
                                Button("Prøv igjen") { Task { await refreshSummaries() } }
                                    .frame(minHeight: 44)
                            }
                        }

                        if preferencesViewModel.showGoalStatusOnHome {
                            Rectangle()
                                .fill(AppColors.separator)
                                .frame(height: 1)
                                .accessibilityHidden(true)
                        }
                        HomeWaterSection(userId: authViewModel.currentUser?.id, date: selectedDate)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .matLoggCardSurface(fill: AppColors.energySurfaceGradient, cornerRadius: 24, shadowEnabled: false, borderEnabled: false)

                    if let receipt = mealReuseViewModel.receipt {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(receipt.title) lagret på enheten")
                                    .font(AppTypography.bodyEmphasis)
                                Button("Angre") {
                                    Task {
                                        if await mealReuseViewModel.undo() { await refreshAfterMealReuse() }
                                    }
                                }
                                .frame(minHeight: 44)
                                .disabled(mealReuseViewModel.isSaving)
                                .accessibilityIdentifier("meal-reuse-undo")
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    if mealReuseViewModel.draft == nil, let error = mealReuseViewModel.errorMessage {
                        ErrorMessageView(error)
                            .font(AppTypography.body)
                            .accessibilityIdentifier("meal-reuse-error")
                    }

                    HStack {
                        Text(mealsTitle)
                            .font(AppTypography.sectionTitle)
                            .foregroundColor(AppColors.ink)
                        Spacer()
                        Button("Se dagslogg") { showDailyLog = true }
                            .font(AppTypography.secondaryEmphasis)
                            .foregroundStyle(AppColors.actionText)
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("home-daily-log")
                    }

                    if overviewModel.shouldShowEmptyDay(userId: authViewModel.currentUser?.id, date: selectedDate) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingen logget ennå")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textSecondary)
                            PrimaryButton(title: "Loggfør første måltid", systemImage: "plus", action: onOpenQuickLog)
                                .accessibilityIdentifier("home-log-food")
                        }
                    }

                    if selectedSummary != nil {
                        ForEach(MealPresentation.all) { meal in
                            MealOverviewCard(
                                meal: meal,
                                logs: logsByMeal[meal.key] ?? [],
                                totals: overviewModel.overview.mealTotals[meal.key] ?? NutritionCalculator.totals(for: []),
                                productName: { productNames[$0] ?? "Ukjent produkt" },
                                productImageURL: { overviewModel.products[$0]?.imageUrl.flatMap(URL.init(string:)) },
                                productImageData: { overviewModel.products[$0]?.localImageData },
                                onOpen: { selectedMealForLog = meal },
                                onEdit: { editingLog = $0 },
                                onAdd: {
                                    appState.selectedMealType = meal.key
                                    onOpenQuickLog()
                                },
                                reuseSuggestion: mealReuseViewModel.suggestions.first { $0.mealType == meal.key },
                                isReusing: mealReuseViewModel.isSaving,
                                onReuse: { suggestion in
                                    Task {
                                        if await mealReuseViewModel.log(suggestion) { await refreshAfterMealReuse() }
                                    }
                                },
                                onAdjustReuse: { mealReuseViewModel.edit($0) },
                                onDismissReuse: { mealReuseViewModel.dismissSuggestion(mealType: meal.key) }
                            )
                        }
                    }

                    HomeQuickProductsSection(userId: authViewModel.currentUser?.id, date: selectedDate,
                        logRevision: logViewModel.mutationRevision, savedMealRevision: savedMealsViewModel.mutationRevision,
                        onSelect: { selectedProduct = $0 })


                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .refreshable {
                isPullRefreshing = true
                defer { isPullRefreshing = false }
                await refreshSummaries()
            }
            .matLoggTabBarScrollClearance()
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showDailyLog) {
                LoggView(initialDate: selectedDate)
            }
            .navigationDestination(item: $selectedMealForLog) { meal in
                LoggView(initialDate: selectedDate, initialMeal: meal.key)
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            appState.logSelectedDate = Date()
            await refreshSummaries()
        }
        .sheet(item: $editingLog) { log in
            EditLogView(
                log: log,
                productName: productNames[log.productId] ?? "Ukjent matvare",
                brand: overviewModel.products[log.productId]?.brand,
                imageURL: overviewModel.products[log.productId]?.imageUrl.flatMap(URL.init(string:)),
                imageData: overviewModel.products[log.productId]?.localImageData,
                onSave: { amount, meal, portion in
                        guard let userId = authViewModel.currentUser?.id else { return false }
                        let success = await logViewModel.updateLog(log, amountG: amount, mealType: meal, userId: userId, portionSelection: portion, clearPortion: portion == nil)
                        if success {
                            await appState.refreshSyncStatus()
                        } else {
                            appState.errorMessage = logViewModel.errorMessage
                        }
                        await refreshSummaries()
                        return success
                }
            )
        }
        .sheet(item: Binding(
            get: { mealReuseViewModel.draft },
            set: { if $0 == nil { mealReuseViewModel.cancelEditing() } }
        )) { _ in
            MealReuseEditorView(onSaved: { await refreshAfterMealReuse() })
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshSummaries() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            appState.logSelectedDate = Date()
            Task { await refreshSummaries() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await refreshSummaries() }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(
                product: product,
                appState: appState,
                onLogComplete: { payload in
                    onLogComplete(payload)
                }
            )
        }
        .onChange(of: logViewModel.mutationRevision) { _, _ in
            Task { await refreshSummaries() }
        }
        .onChange(of: savedMealsViewModel.mutationRevision) { _, _ in
            Task { await refreshSummaries() }
        }
        .onChange(of: appState.logSelectedDate) { _, _ in
            Task { await refreshSummaries() }
        }

    }

    private func refreshAfterMealReuse() async {
        if let userId = authViewModel.currentUser?.id {
            await logViewModel.loadTodaysSummary(userId: userId)
        }
        await appState.refreshSyncStatus()
        await refreshSummaries()
    }

    private func refreshSummaries() async {
        let userId = authViewModel.currentUser?.id
        let date = selectedDate
        async let summary: Void = overviewModel.load(userId: userId, date: date)
        async let reuse: Void = loadMealReuse(userId: userId, date: date)
        _ = await (summary, reuse)
    }

    private func loadMealReuse(userId: UUID?, date: Date) async {
        if let userId { await mealReuseViewModel.load(userId: userId, date: date) }
    }

    private func homeHeadingText(at date: Date) -> some View {
        Text(homeHeading(at: date))
            .font(AppTypography.hero)
            .foregroundColor(AppColors.deepInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var loggingStreakBadge: some View {
        if let count = overviewModel.loggingStreak {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .foregroundColor(count > 0 ? AppColors.accent : AppColors.textSecondary)
                Text(count, format: .number)
                    .foregroundColor(count > 0 ? AppColors.deepInk : AppColors.textSecondary)
                    .monospacedDigit()
            }
            .font(AppTypography.bodyEmphasis)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(count == 1 ? "Mat logget 1 dag på rad" : "Mat logget \(count) dager på rad")
        }
    }

    private func homeHeading(at now: Date) -> String {
        let calendar = Calendar.current
        guard calendar.isDate(selectedDate, inSameDayAs: now) else { return "Dagsoversikt" }
        switch calendar.component(.hour, from: now) {
        case 5..<11: return "God morgen"
        case 11..<17: return "God ettermiddag"
        case 17..<23: return "God kveld"
        default: return "Hei"
        }
    }

    private var selectedDateBinding: Binding<Date> {
        Binding(
            get: { appState.logSelectedDate },
            set: { appState.logSelectedDate = $0 }
        )
    }

    private var selectedDate: Date {
        appState.logSelectedDate
    }

    private var mealsTitle: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Måltider i dag" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Måltider i går" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "Måltider i morgen" }
        return "Måltider \(shortDateLabel)"
    }

    private var shortDateLabel: String {
        selectedDate.formatted(
            .dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO"))
        )
    }

}

private struct HomeSyncBanner: View {
    @EnvironmentObject private var appState: AppState
    var body: some View {
                    if appState.isSyncAvailable && appState.unsyncedSyncCount > 0 {
                        Label(
                            homeSyncStatusText,
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(homeSyncStatusText)
                    }


    }
    private var homeSyncStatusText: String {
        let count = appState.unsyncedSyncCount
        let noun = count == 1 ? "endring" : "endringer"
        if appState.networkAvailability == .offline {
            return "Du er offline. \(count) \(noun) er lagret på enheten og venter på synk"
        }
        if appState.isSyncing || appState.inFlightSyncCount > 0 {
            return "Synkroniserer \(count) \(noun)"
        }
        if appState.failedSyncCount > 0 {
            return "\(count) \(noun) er lagret på enheten. \(appState.failedSyncCount) krever handling"
        }
        return "\(count) \(noun) lagret på enheten og venter på synk"
    }

}

private struct HomeWaterSection: View {
    @EnvironmentObject private var waterViewModel: WaterViewModel
    let userId: UUID?
    let date: Date
    var body: some View { WaterCardView(viewModel: waterViewModel, userId: userId, date: date, compact: true, embedded: true) }
}

private struct HomeQuickProductsSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var quickLogViewModel: QuickLogViewModel
    let userId: UUID?
    let date: Date
    let logRevision: Int
    let savedMealRevision: Int
    let onSelect: (Product) -> Void
    private struct RefreshContext: Equatable {
        let userId: UUID?
        let date: Date
        let logRevision: Int
        let savedMealRevision: Int
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hurtigvalg")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.deepInk)
                Spacer()
                ActivityIndicatorSlot(isActive: quickLogViewModel.showsLoadingFeedback && !quickLogViewModel.products.isEmpty,
                                      label: "Oppdaterer hurtigvalg")
            }
            if let error = quickLogViewModel.errorMessage, !quickLogViewModel.products.isEmpty {
                ErrorMessageView(error).font(AppTypography.caption)
                Button("Prøv igjen") { Task { await quickLogViewModel.load(userId: userId) } }.frame(minHeight: 44)
            }
            if (quickLogViewModel.isLoading || !quickLogViewModel.hasLoaded) && quickLogViewModel.products.isEmpty {
                ProgressView("Henter hurtigvalg …")
            } else if let error = quickLogViewModel.errorMessage, quickLogViewModel.products.isEmpty {
                ErrorMessageView(error)
                    .font(AppTypography.secondary)
                Button("Prøv igjen") {
                    Task { await quickLogViewModel.load(userId: userId) }
                }
                .frame(minHeight: 44)
            } else if quickLogViewModel.products.isEmpty {
                Text("Favoritter og nylig brukte matvarer dukker opp her.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickLogViewModel.products.prefix(6)) { product in
                            Button {
                                onSelect(product)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(product.name)
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                        .lineLimit(2)
                                    Text("\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal per 100 \(product.amountUnit.rawValue)")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(width: 132, alignment: .leading)
                                .frame(minHeight: 76, alignment: .leading)
                                .padding(14)
                                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await quickLogViewModel.load(userId: userId) } }
        }
        .task(id: RefreshContext(userId: userId, date: date, logRevision: logRevision, savedMealRevision: savedMealRevision)) {
            if let userId { await quickLogViewModel.load(userId: userId) }
        }
    }

}


struct MealPresentation: Identifiable, Hashable {
    let key: String
    let title: String
    let icon: String
    var id: String { key }
    var tint: Color { AppColors.mealTint(for: key) }

    static let all: [MealPresentation] = [
        .init(key: "frokost", title: "Frokost", icon: "sunrise.fill"),
        .init(key: "lunsj", title: "Lunsj", icon: "sun.max.fill"),
        .init(key: "middag", title: "Middag", icon: "fork.knife"),
        .init(key: "snacks", title: "Kveldsmat", icon: "moon.stars.fill")
    ]
}

struct QuickSearchBar: View {
    let onSearch: () -> Void
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSearch) {
                Label("Søk etter mat", systemImage: "magnifyingglass")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.deepInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(AppColors.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppColors.controlBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Åpner matvaresøk")

            Button(action: onScan) {
                Label("Skann", systemImage: "barcode.viewfinder")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.background)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 50)
                    .background(AppColors.deepInk, in: Capsule())
            }
            .accessibilityLabel("Skann strekkode")
        }
    }
}

struct MealOverviewCard: View {
    let meal: MealPresentation
    let logs: [FoodLog]
    let totals: NutritionBreakdown
    let productName: (UUID) -> String
    var productImageURL: (UUID) -> URL? = { _ in nil }
    var productImageData: (UUID) -> Data? = { _ in nil }
    let onOpen: () -> Void
    var onEdit: (FoodLog) -> Void = { _ in }
    let onAdd: () -> Void
    var reuseSuggestion: MealReuseSuggestion? = nil
    var isReusing = false
    var onReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onAdjustReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onDismissReuse: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: meal.icon)
                    .font(AppTypography.secondaryEmphasis)
                    .symbolRenderingMode(.monochrome)
                    .foregroundColor(AppColors.deepInk.opacity(0.8))
                    .frame(width: 30, height: 30)
                    .background(meal.tint.opacity(0.14), in: Circle())
                    .accessibilityHidden(true)
                Button(action: onOpen) {
                    Text(meal.title)
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.deepInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Åpne \(meal.title)")
                .accessibilityIdentifier("home-meal-open-\(meal.key)")
                Spacer()
                Button(action: onAdd) {
                    Text("+ Legg til")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundColor(AppColors.actionText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if logs.isEmpty, let suggestion = reuseSuggestion {
                MealReuseSuggestionView(
                    suggestion: suggestion,
                    isSaving: isReusing,
                    onLog: { onReuse(suggestion) },
                    onAdjust: { onAdjustReuse(suggestion) },
                    onDismiss: onDismissReuse
                )
            } else if logs.isEmpty {
                Text("Ikke logget ennå")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(logs.prefix(3)) { log in
                        Button { onEdit(log) } label: {
                            HStack(alignment: .top, spacing: 12) {
                                ProductThumbnailView(url: productImageURL(log.productId), localData: productImageData(log.productId), size: 52, imagePadding: 2)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(productName(log.productId))
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection))
                                        .font(AppTypography.secondary)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rediger \(productName(log.productId)), \(PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection))")
                        .accessibilityIdentifier("home-log-row-\(log.id.uuidString)")
                    }
                    if logs.count > 3 {
                        Text("+ \(logs.count - 3) flere")
                            .font(AppTypography.secondaryEmphasis).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(NutritionDisplay.wholeCalories(totals.calories)) kcal")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.deepInk)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            mealMacros(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            mealMacros(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Totalt for \(meal.title): \(NutritionDisplay.wholeCalories(totals.calories)) kilokalorier, proteiner \(NutritionDisplay.wholeGrams(totals.protein)) gram, karbohydrater \(NutritionDisplay.wholeGrams(totals.carbs)) gram, fett \(NutritionDisplay.wholeGrams(totals.fat)) gram")
            }
        }
        .padding(16)
        .matLoggCardSurface(cornerRadius: 24, borderEnabled: false)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            if !logs.isEmpty { onOpen() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(logs.isEmpty ? "Bruk Legg til-knappen for å logge mat" : "Åpner alle innslag med redigering")
    }

    @ViewBuilder
    private func mealMacros(protein: Float, carbs: Float, fat: Float) -> some View {
        macroLabel("P", value: protein, tint: AppColors.macroProteinTint)
        macroLabel("K", value: carbs, tint: AppColors.macroCarbTint)
        macroLabel("F", value: fat, tint: AppColors.macroFatTint)
    }

    private func macroLabel(_ label: String, value: Float, tint: Color) -> some View {
        Text("\(label) \(NutritionDisplay.wholeGrams(value)) g")
            .font(AppTypography.captionEmphasis)
            .foregroundColor(AppColors.deepInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12), in: Capsule())
            .fixedSize()
    }

}


struct MealTypeSelector: View {
    @EnvironmentObject var appState: AppState


    var body: some View {
        HStack(spacing: 8) {
            ForEach(MealPresentation.all) { meal in
                MealChip(
                    title: meal.key == "snacks" ? "Snacks" : meal.title,
                    isSelected: appState.selectedMealType == meal.key,
                    action: { appState.selectedMealType = meal.key }
                )
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct ReceiptPayload: Identifiable {
    let id = UUID()
    let product: Product
    let amountG: Double
    let amountUnit: AmountUnit
    let mealType: String
    let loggedDate: Date
    var portionSelection: PortionSelection? = nil
    var logID: UUID? = nil
    var ownerID: UUID? = nil
}

struct ScanButtonLarge: View {
    let action: () -> Void

    var body: some View {
        PrimaryButton(title: "Skann", systemImage: "barcode.viewfinder", height: 72, action: action)
    }
}

struct ScanHistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject private var historyViewModel: ScanHistoryViewModel
    private var recentScans: [ScanHistory] { historyViewModel.scans }
    private var productsByID: [UUID: Product] { historyViewModel.products }
    @State private var selectedProduct: Product?
    @State private var showMissingProductAlert = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var showScanCamera = false
    @State private var showRawMaterials = false

    var body: some View {
        NavigationStack {
            VStack {
                Text("Nylig brukt")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)

                if historyViewModel.isLoading {
                    ProgressView("Henter skannehistorikk …")
                }
                if let error = historyViewModel.errorMessage {
                    ErrorMessageView(error)
                    Button("Prøv igjen") { Task { await historyViewModel.load(userId: authViewModel.currentUser?.id) } }
                        .frame(minHeight: 44)
                }
                if recentScans.isEmpty && !historyViewModel.isLoading && historyViewModel.errorMessage == nil {
                    Text("Ingen nylige skanninger")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(recentScans) { scan in
                        Button(action: {
                            if let product = productsByID[scan.productId] {
                                selectedProduct = product
                            } else {
                                showMissingProductAlert = true
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(productName(for: scan))
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.ink)
                                    Text("Skanner for \(scan.scannedAt.timeAgoDisplay())")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .bottom) {
            if let payload = receiptPayload {
                LogToastView(
                    payload: payload,
                    isUndoing: isUndoingReceipt,
                    onUndo: { undoLogging(payload) },
                    onDismiss: { dismissReceipt() }
                )
                .padding(16)
                .transition(.logToast)
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            await historyViewModel.load(userId: authViewModel.currentUser?.id)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product, appState: appState) { payload in
                receiptPayload = payload
            }
        }
        .fullScreenCover(isPresented: $showScanCamera) {
            CameraView(
                onLogComplete: { _ in },
                onSearch: { showRawMaterials = true }
            )
        }
        .fullScreenCover(isPresented: $showRawMaterials) {
            RawMaterialsSearchView { payload in
                showRawMaterials = false
                receiptPayload = payload
            }
            .environmentObject(appState)
        }
        .alert("Produkt ikke tilgjengelig", isPresented: $showMissingProductAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Vi finner ikke produktdata lokalt. Prøv å skanne på nytt.")
        }
    }

    private func productName(for scan: ScanHistory) -> String {
        productsByID[scan.productId]?.name ?? "Ukjent produkt"
    }

    private func dismissReceipt() {
        if UIAccessibility.isReduceMotionEnabled {
            receiptPayload = nil
        } else {
            withAnimation(.smooth(duration: 0.32)) { receiptPayload = nil }
        }
    }

    private func undoLogging(_ payload: ReceiptPayload) {
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id,
              payload.ownerID == nil || payload.ownerID == userId else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate,
                logID: payload.logID
            )
            if succeeded {
                dismissReceipt()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage ?? "Kunne ikke angre loggingen."
            }
            isUndoingReceipt = false
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    private let productSelectionContent: ((Product) -> AnyView)?
    let onLogComplete: (ReceiptPayload) -> Void
    let onSearch: () -> Void

    @StateObject private var cameraAuthorization: CameraAuthorizationViewModel

    private var scannedBarcode: String? { productViewModel.scannedBarcode }
    private var scannedProduct: Product? { productViewModel.scannedProduct }
    private var isLoading: Bool { productViewModel.isScanning }
    @State private var isTorchOn = false
    @State private var isTorchAvailable = false
    @State private var scanHelpTitle: String?
    @State private var scanHelpHints: [ScanHelpHint] = []
    @State private var showScanHelp = false
    @State private var showProductDetail = false
    @State private var showProductNotFound = false
    @State private var showManualProduct = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false

    init(
        onLogComplete: @escaping (ReceiptPayload) -> Void,
        onSearch: @escaping () -> Void = {},
        authorizationProvider: any CameraAuthorizationProviding = CameraAuthorizationService(),
        productSelectionContent: ((Product) -> AnyView)? = nil
    ) {
        self.productSelectionContent = productSelectionContent
        self.onLogComplete = onLogComplete
        self.onSearch = onSearch
        _cameraAuthorization = StateObject(
            wrappedValue: CameraAuthorizationViewModel(authorizationProvider: authorizationProvider)
        )
    }

    var body: some View {
        ZStack {
            scannerContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.imageViewerBackground)
                .ignoresSafeArea()

            if cameraAuthorization.state == .authorized {
                ScannerFocusOverlay(isLoading: isLoading)
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [AppColors.scannerControl, AppColors.scannerGradientClear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 170)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                scannerTopBar
                Spacer(minLength: 0)
                if cameraAuthorization.state == .authorized {
                    scannerBottomControls
                }
            }
            .padding(.horizontal, 16)
            .safeAreaPadding(.top, 8)
            .safeAreaPadding(.bottom, 16)
        }
        .overlay(alignment: .bottom) {
            if let payload = receiptPayload {
                LogToastView(
                    payload: payload,
                    isUndoing: isUndoingReceipt,
                    onUndo: { undoLogging(payload) },
                    onDismiss: { dismissReceipt() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .transition(.logToast)
            }
        }
        .onDisappear {
            isTorchOn = false
            if !showManualProduct && !showProductDetail { productViewModel.resetScan() }
        }
        .onChange(of: productViewModel.scannedProduct?.id) { _, id in
            if id != nil, !showManualProduct {
                showScanHelp = false
                showProductDetail = true
            }
        }
        .onChange(of: productViewModel.scanFailure) { _, failure in
            showProductNotFound = failure != nil
        }
        .task {
            cameraAuthorization.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            cameraAuthorization.refresh()
        }
        .onChange(of: cameraAuthorization.state) { _, state in
            guard state == .authorized else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: "Kamera klart. Plasser en strekkode eller Data Matrix-kode foran kameraet."
            )
        }
        .sheet(isPresented: $showProductDetail, onDismiss: {
            productViewModel.resetScan()
        }) {
            if let product = scannedProduct {
                if let productSelectionContent {
                    productSelectionContent(product)
                } else {
                ProductDetailView(
                    product: product,
                    appState: appState,
                    onLogComplete: { payload in
                        receiptPayload = payload
                        onLogComplete(payload)
                    }
                )
                }
            }
        }
        .fullScreenCover(isPresented: $showManualProduct, onDismiss: {
            if scannedProduct != nil {
                showProductDetail = true
            }
        }) {
            ManualProductView(
                barcode: scannedBarcode,
                saveProduct: { product in
                    guard let userId = authViewModel.currentUser?.id else {
                        throw DatabaseServiceError.unavailable
                    }
                    try await productViewModel.saveManualProduct(product, ownerUserId: userId)
                }
            ) { product in
                productViewModel.acceptManualScan(product)
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        await productViewModel.recordScan(productId: product.id, userId: userId)
                        await appState.refreshSyncStatus()
                    }
                }
            }
        }
        .alert(productViewModel.scanFailure?.title ?? "Produktoppslag", isPresented: $showProductNotFound) {
            if productViewModel.scanFailure == .unavailable {
                Button("Prøv igjen") {
                    guard let barcode = scannedBarcode else { return }
                    productViewModel.resetScan()
                    Task { await productViewModel.scan(barcode: barcode, ownerUserId: authViewModel.currentUser?.id) }
                }
            }
            Button("Registrer manuelt") { showManualProduct = true }
            Button("Avbryt", role: .cancel) { productViewModel.resetScan() }
        } message: {
            Text(productViewModel.scanFailure?.message ?? "")
        }
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch cameraAuthorization.state {
        case .authorized:
            BarcodeScannerView(
                onBarcodeDetected: handleBarcodeDetected,
                onError: handleError,
                onCameraUnavailable: handleCameraUnavailable,
                onTorchAvailabilityChanged: { isAvailable in
                    isTorchAvailable = isAvailable
                    if !isAvailable { isTorchOn = false }
                },
                torchOn: $isTorchOn
            )
        case .checking, .requesting:
            cameraAuthorizationProgress
        case .needsRequest:
            cameraPermissionRequest
        case .denied:
            cameraPermissionDenied
        case .restricted:
            cameraPermissionRestricted
        case .unavailable:
            cameraUnavailable
        }
    }

    private var scannerTopBar: some View {
        HStack {
            ScannerOverlayButton(
                systemImage: "xmark",
                accessibilityLabel: "Avbryt",
                action: { dismiss() }
            )

            Spacer()

            if cameraAuthorization.state == .authorized, isTorchAvailable {
                ScannerOverlayButton(
                    systemImage: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                    accessibilityLabel: isTorchOn ? "Slå av lommelykt" : "Slå på lommelykt",
                    isSelected: isTorchOn,
                    action: { isTorchOn.toggle() }
                )
                .accessibilityValue(isTorchOn ? "På" : "Av")
            }
        }
    }

    private var scannerBottomControls: some View {
        VStack(spacing: 12) {
            if productViewModel.isScanTakingLong {
                Text("Oppslaget tar litt tid. Du kan søke eller registrere varen manuelt.")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColors.scannerText)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(AppColors.scannerPanel, in: RoundedRectangle(cornerRadius: 16))
            }
            if showScanHelp, let scanHelpTitle {
                VStack(spacing: 6) {
                    Text(scanHelpTitle)
                        .font(AppTypography.bodyEmphasis)
                    ForEach(scanHelpHints) { hint in
                        Text(hint.text)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.scannerSecondaryText)
                    }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.scannerText)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(AppColors.scannerPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            VStack(spacing: 10) {
                ScannerActionButton(title: "Søk etter vare", systemImage: "magnifyingglass") {
                    openSearch()
                }
                ScannerActionButton(title: "Registrer manuelt", systemImage: "square.and.pencil") {
                    productViewModel.resetScan()
                    showManualProduct = true
                }
            }
        }
    }

    private var cameraAuthorizationProgress: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppColors.scannerText)
            Text(cameraAuthorization.state == .requesting ? "Venter på kameratilgang …" : "Sjekker kameratilgang …")
                .font(AppTypography.body)
                .foregroundColor(AppColors.scannerMutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var cameraPermissionRequest: some View {
        cameraPermissionMessage(
            icon: "barcode.viewfinder",
            title: "Skann strekkoder med kameraet",
            message: "MatLogg bruker kameraet bare til å lese strekkoder på matvarer. Ingen bilder lagres.",
            primaryTitle: "Gi kameratilgang",
            primarySystemImage: "camera.fill",
            primaryAction: {
                Task { await cameraAuthorization.requestAccess() }
            }
        )
    }

    private var cameraPermissionDenied: some View {
        cameraPermissionMessage(
            icon: "camera.fill",
            title: "Kameratilgang er slått av",
            message: "Gi MatLogg kameratilgang i Innstillinger for å skanne strekkoder.",
            primaryTitle: "Åpne Innstillinger",
            primarySystemImage: "gearshape.fill",
            primaryAction: openAppSettings
        )
    }

    private var cameraPermissionRestricted: some View {
        cameraPermissionMessage(
            icon: "camera.fill",
            title: "Kameraet kan ikke brukes",
            message: "Kameratilgang er begrenset på denne enheten, for eksempel av Skjermtid eller en administrert profil.",
            primaryTitle: nil,
            primarySystemImage: nil,
            primaryAction: {}
        )
    }

    private var cameraUnavailable: some View {
        cameraPermissionMessage(
            icon: "camera.fill",
            title: "Kameraet er ikke tilgjengelig",
            message: "MatLogg får ikke startet kameraet på denne enheten akkurat nå. Du kan fortsatt registrere produktet manuelt eller velge en annen metode.",
            primaryTitle: nil,
            primarySystemImage: nil,
            primaryAction: {}
        )
    }

    private func cameraPermissionMessage(
        icon: String,
        title: String,
        message: String,
        primaryTitle: String?,
        primarySystemImage: String?,
        primaryAction: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 42, weight: .semibold))
                .accessibilityHidden(true)

            Text(title)
                .font(AppTypography.title)
                .multilineTextAlignment(.center)

            Text(message)
                .font(AppTypography.body)
                .foregroundColor(AppColors.scannerMutedText)
                .multilineTextAlignment(.center)

            if let primaryTitle {
                PrimaryButton(
                    title: primaryTitle,
                    systemImage: primarySystemImage,
                    action: primaryAction
                )
            }

            Button("Registrer manuelt") {
                productViewModel.resetScan()
                showManualProduct = true
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(AppColors.scannerText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                Capsule().stroke(AppColors.scannerOutline, lineWidth: 1)
            )

            Button("Velg en annen metode") { dismiss() }
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.scannerText)
                .frame(minHeight: 44)
                .accessibilityHint("Lukker kameraet og går tilbake til de andre måtene å legge til mat på")
        }
        .foregroundColor(AppColors.scannerText)
        .padding(24)
        .frame(maxWidth: 420, maxHeight: .infinity)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }

    private func openSearch() {
        productViewModel.resetScan()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSearch()
        }
    }

    private func handleBarcodeDetected(_ scannedCode: ScannedBarcode) {
        guard !isLoading, !showManualProduct, !showProductDetail, !showProductNotFound else { return }

        let barcode: String
        do {
            barcode = try productViewModel.lookupBarcode(from: scannedCode)
        } catch {
            presentScanHelp(
                title: "Denne koden inneholder ikke et gyldig produktnummer",
                hints: [.anotherCode, .manualEntry]
            )
            return
        }

        guard scannedBarcode != barcode else { return }

        UIAccessibility.post(notification: .announcement, argument: "Kode funnet. Henter produkt.")
        HapticFeedbackService.shared.trigger(.barcodeDetected, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.barcodeDetected, isEnabled: preferencesViewModel.soundFeedbackEnabled)
        Task {
            await productViewModel.scan(barcode: barcode, ownerUserId: authViewModel.currentUser?.id)
            await appState.refreshSyncStatus()
        }
    }

    private func dismissReceipt() {
        if UIAccessibility.isReduceMotionEnabled {
            receiptPayload = nil
        } else {
            withAnimation(.smooth(duration: 0.32)) { receiptPayload = nil }
        }
    }

    private func undoLogging(_ payload: ReceiptPayload) {
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id,
              payload.ownerID == nil || payload.ownerID == userId else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate,
                logID: payload.logID
            )
            if succeeded {
                dismissReceipt()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage ?? "Kunne ikke angre loggingen."
            }
            isUndoingReceipt = false
        }
    }

    private func handleError(_ error: String) {
        presentScanHelp(
            title: error,
            hints: [.holdStill, .moreLight, .moveCloser]
        )
        HapticFeedbackService.shared.trigger(.error, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.error, isEnabled: preferencesViewModel.soundFeedbackEnabled)
    }

    private func handleCameraUnavailable() {
        isTorchOn = false
        isTorchAvailable = false
        cameraAuthorization.reportCameraUnavailable()
    }

    private func presentScanHelp(title: String, hints: [ScanHelpHint]) {
        scanHelpTitle = title
        scanHelpHints = hints.reduce(into: []) { unique, hint in
            if !unique.contains(hint) { unique.append(hint) }
        }
        showScanHelp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if scanHelpTitle == title {
                showScanHelp = false
            }
        }
    }
}

struct ManualAddView: View {
    @Environment(\.dismiss) var dismiss
    let onOpenRawMaterials: (() -> Void)?
    @State private var productName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Råvarer") {
                    Button(action: {
                        dismiss()
                        onOpenRawMaterials?()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "leaf")
                            Text("Søk / Råvarer")
                        }
                    }
                    Text("Bruk Matvaretabellen for rask logging uten strekkode.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .listRowBackground(AppColors.surface)

                Section("Produktdetaljer") {
                    TextField("Produktnavn", text: $productName)
                    TextField("Kalorier (per 100g)", text: $calories)
                        .keyboardType(.numberPad)
                    TextField("Protein (g per 100g)", text: $protein)
                        .keyboardType(.decimalPad)
                    TextField("Karbohydrater (g per 100g)", text: $carbs)
                        .keyboardType(.decimalPad)
                    TextField("Fett (g per 100g)", text: $fat)
                        .keyboardType(.decimalPad)
                }
                .listRowBackground(AppColors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.action)
            .navigationTitle("Legg til produkt")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Legg til") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.actionText)
                }
            }
        }
    }
}

struct FavoritesTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Favoritter kommer snart")
                    .foregroundColor(AppColors.textSecondary)
            }
            .navigationTitle("Favoritter")
        }
    }
}

struct SearchHubView: View {
    let onScan: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    var onSavedMealLogComplete: () -> Void = {}

    var body: some View {
        NavigationStack {
            FoodSearchView(isTab: true, onScan: onScan, onLogComplete: onLogComplete,
                           onSavedMealLogComplete: onSavedMealLogComplete)
                .navigationTitle("Søk")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let database = DatabaseService()
    HomeView()
        .environmentObject(AppState(databaseService: database))
        .environmentObject(LogViewModel(repository: database))
        .environmentObject(MealReuseViewModel(repository: database))
        .environmentObject(SavedMealsViewModel(savedMealRepository: database, foodLogRepository: database, photoRepository: LocalMealPhotoRepository()))
        .environmentObject(ProductViewModel(repository: database))
        .environment(\.foodLogRepository, database)
        .environment(\.foodSearchRepository, DefaultFoodSearchRepository(
            products: database, catalog: MatvaretabellenService(), remote: APIService(), recentFoods: database
        ))
        .environmentObject(HealthProfileViewModel(repository: database))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
        .environmentObject(WaterViewModel(repository: database))
        .environmentObject(ProfileExportViewModel(exporter: UserDataExportService(logRepository: database, savedMealRepository: database, waterRepository: database, healthRepository: database, productRepository: database, personalDetailsStore: UserDefaultsPersonalDetailsStore(), profileDataRepository: database)))
        .environmentObject(PersonalDetailsViewModel(store: UserDefaultsPersonalDetailsStore()))
        .environmentObject(ProfileFavoritesViewModel(repository: database))
}

extension Date {
    func timeAgoDisplay() -> String {
        formatted(Date.RelativeFormatStyle(
            presentation: .named,
            unitsStyle: .wide,
            locale: Locale(identifier: "nb_NO")
        ))
    }
}

private struct ScannerFocusOverlay: View {
    let isLoading: Bool

    private let focusSize = CGSize(width: 300, height: 180)
    private let focusOffset: CGFloat = -42

    var body: some View {
        ZStack {
            AppColors.scannerScrim
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .frame(width: focusSize.width, height: focusSize.height)
                                .offset(y: focusOffset)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

            ScannerCornerFrame()
                .stroke(
                    isLoading ? AppColors.info : AppColors.scannerText,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
                .frame(width: focusSize.width, height: focusSize.height)
                .shadow(color: AppColors.scannerShadow, radius: 3, y: 1)
                .overlay(alignment: .top) {
                    Group {
                        if isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .tint(AppColors.scannerText)
                                Text("Henter produkt …")
                                    .font(AppTypography.bodyEmphasis)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppColors.scannerPanel, in: Capsule())
                            .accessibilityElement(children: .combine)
                        } else {
                            VStack(spacing: 4) {
                                Text("Plasser koden i rammen")
                                    .font(AppTypography.bodyEmphasis)
                                Text("Strekkode eller Data Matrix")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.scannerSecondaryText)
                            }
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppColors.scannerHintPanel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .foregroundStyle(AppColors.scannerText)
                    .offset(y: focusSize.height + 32)
                }
                .offset(y: focusOffset)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct ScannerCornerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength: CGFloat = 34
        let radius: CGFloat = 24
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )

        return path
    }
}

private struct ScannerOverlayButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? AppColors.onVibrant : AppColors.scannerText)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? AppColors.brand : AppColors.scannerControl,
                    in: Circle()
                )
                .overlay(Circle().stroke(AppColors.scannerControlBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ScannerActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(AppTypography.bodyEmphasis)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.scannerText)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .background(AppColors.scannerPanel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.scannerPanelBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BarcodeScannerView Wrapper

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeDetected: (ScannedBarcode) -> Void
    let onError: (String) -> Void
    let onCameraUnavailable: () -> Void
    let onTorchAvailabilityChanged: (Bool) -> Void
    @Binding var torchOn: Bool

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onError = onError
        controller.onCameraUnavailable = onCameraUnavailable
        controller.onTorchAvailabilityChanged = onTorchAvailabilityChanged
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.setTorch(on: torchOn)
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeScannerViewController, coordinator: ()) {
        uiViewController.stopScanning()
    }
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((ScannedBarcode) -> Void)?
    var onError: ((String) -> Void)?
    var onCameraUnavailable: (() -> Void)?
    var onTorchAvailabilityChanged: ((Bool) -> Void)?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.matlogg.barcode-scanner.session", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var lastScannedCode: String?
    private var lastScanTime: Date = Date()
    private var videoDevice: AVCaptureDevice?
    private var isSessionConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewRotation()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sessionQueue.async { [weak self] in
            self?.startSessionIfPossible()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.setTorchOnSessionQueue(on: false)
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    private func configureSession() {
        guard !isSessionConfigured else { return }

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            reportCameraUnavailable()
            return
        }
        videoDevice = videoCaptureDevice

        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            reportCameraUnavailable()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            reportCameraUnavailable()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()

        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            let requestedTypes: [AVMetadataObject.ObjectType] = [
                .ean8,
                .ean13,
                .upce,
                .code128,
                .code39,
                .code93,
                .dataMatrix
            ]
            metadataOutput.metadataObjectTypes = requestedTypes.filter {
                metadataOutput.availableMetadataObjectTypes.contains($0)
            }
        } else {
            reportCameraUnavailable()
            return
        }

        isSessionConfigured = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = self.view.bounds
            self.previewLayer = previewLayer
            self.rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: videoCaptureDevice,
                previewLayer: previewLayer
            )
            self.view.layer.insertSublayer(previewLayer, at: 0)
            self.updatePreviewRotation()
            self.onTorchAvailabilityChanged?(videoCaptureDevice.hasTorch)
        }
    }

    private func startSessionIfPossible() {
        guard isSessionConfigured, !captureSession.isRunning else { return }
        captureSession.startRunning()
    }

    private func updatePreviewRotation() {
        guard let angle = rotationCoordinator?.videoRotationAngleForHorizonLevelPreview,
              let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func reportCameraUnavailable() {
        DispatchQueue.main.async { [weak self] in
            self?.onTorchAvailabilityChanged?(false)
            self?.onCameraUnavailable?()
        }
    }

    func setTorch(on: Bool) {
        sessionQueue.async { [weak self] in
            self?.setTorchOnSessionQueue(on: on)
        }
    }

    private func setTorchOnSessionQueue(on: Bool) {
        guard let device = videoDevice,
              device.hasTorch,
              device.isTorchModeSupported(on ? .on : .off) else { return }

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if on {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
            } else {
                device.torchMode = .off
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.onError?("Kunne ikke slå på lommelykten")
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        for metadata in metadataObjects {
            if let readableObject = metadata as? AVMetadataMachineReadableCodeObject {
                if let stringValue = readableObject.stringValue {
                    // Debounce: ignore same code within 1 second
                    let now = Date()
                    if lastScannedCode != stringValue || now.timeIntervalSince(lastScanTime) > 1.0 {
                        lastScannedCode = stringValue
                        lastScanTime = now
                        guard let symbology = symbology(for: readableObject.type) else { continue }
                        onBarcodeDetected?(ScannedBarcode(rawValue: stringValue, symbology: symbology))
                    }
                }
            }
        }
    }

    private func symbology(for type: AVMetadataObject.ObjectType) -> ScannedBarcode.Symbology? {
        switch type {
        case .ean8: return .ean8
        case .ean13: return .ean13
        case .upce: return .upce
        case .code128: return .code128
        case .code39: return .code39
        case .code93: return .code93
        case .dataMatrix: return .gs1DataMatrix
        default: return nil
        }
    }
}

private enum ScanHelpHint: String, Identifiable {
    case anotherCode, manualEntry, holdStill, moreLight, moveCloser
    var id: String { rawValue }
    var text: String {
        switch self {
        case .anotherCode: return "Prøv en annen kode på pakken"
        case .manualEntry: return "Du kan også søke eller registrere produktet manuelt"
        case .holdStill: return "Hold kamera rolig"
        case .moreLight: return "Mer lys"
        case .moveCloser: return "Flytt nærmere strekkoden"
        }
    }
}
