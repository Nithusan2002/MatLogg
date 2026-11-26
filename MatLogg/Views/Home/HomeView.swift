import SwiftUI
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var diarySelection: MatLoggDiarySelectionPresentation?
    private var isDiarySelecting: Bool { diarySelection != nil }
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
                onDeleteComplete: {
                    dismissReceipt()
                    savedMealsViewModel.dismissReceipt()
                },
                onLogComplete: { payload in
                    Task { await loadTodaysSummary() }
                    receiptPayload = payload
                },
                allowsMascotGreeting: !navigation.isOnboarding && navigation.selectedTab == .home
                    && !showAddActions && !showScanCamera && !showRawMaterials
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
        .onPreferenceChange(MatLoggDiarySelectionKey.self) { presentation in
            if presentation != nil { receiptPayload = nil }
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.24)) {
                diarySelection = presentation
            }
        }
        .environment(\.matLoggTabBarScrollMargin, isTabEditing ? 0 : tabBarScrollMargin)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isTabEditing {
                MatLoggTabBar(selection: tabSelection, diarySelection: diarySelection)
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
            if let payload = receiptPayload, !isDiarySelecting {
                LogToastView(
                    payload: payload,
                    isUndoing: isUndoingReceipt,
                    onUndo: { undoLogging(payload) },
                    onDismiss: { dismissReceipt() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, tabBarScrollMargin)
                .transition(.logToast)
            } else if let receipt = navigation.savedMealReceipt, !isDiarySelecting {
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
        .onChange(of: receiptPayload?.id) { _, id in
            if id != nil { logViewModel.dismissCopyReceipt() }
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
    let onDeleteComplete: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    var allowsMascotGreeting = true

    var body: some View {
        if let repository {
            HomeTabContent(repository: repository, appState: appState, logViewModel: logViewModel,
                authViewModel: authViewModel, savedMealsViewModel: savedMealsViewModel,
                healthProfileViewModel: healthProfileViewModel, preferencesViewModel: preferencesViewModel,
                onOpenQuickLog: onOpenQuickLog, onDeleteComplete: onDeleteComplete, onLogComplete: onLogComplete,
                allowsMascotGreeting: allowsMascotGreeting)
        } else {
            ContentUnavailableView("Oversikt er utilgjengelig", systemImage: "fork.knife")
        }
    }
}

private struct HomeTabContent: View {
    @EnvironmentObject private var productViewModel: ProductViewModel
    let savedMealsViewModel: SavedMealsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.matLoggTabBarScrollMargin) private var tabBarScrollMargin
    @EnvironmentObject var mealReuseViewModel: MealReuseViewModel
    let appState: AppState
    let logViewModel: LogViewModel
    let healthProfileViewModel: HealthProfileViewModel
    let authViewModel: AuthViewModel
    let preferencesViewModel: PreferencesViewModel
    let onOpenQuickLog: () -> Void
    let onDeleteComplete: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    let allowsMascotGreeting: Bool
    @State private var isPullRefreshing = false
    @StateObject private var overviewModel: HomeOverviewViewModel
    private var selectedSummary: DailySummary? {
        guard let summary = overviewModel.overview.summary,
              Calendar.current.isDate(summary.date, inSameDayAs: selectedDate) else { return nil }
        return summary
    }
    private var productNames: [UUID: String] { overviewModel.overview.productNames }
    @State private var collapsedMeals: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @StateObject private var selection: LogScreenViewModel
    @StateObject private var copyPresentation: DayCopyReceiptViewModel
    @State private var savedMealSource: SavedMealCreationSource?
    @State private var showBatchDeletion = false
    @State private var editingLog: FoodLog?
    private var isSummaryLoading: Bool { overviewModel.isLoading }

    init(repository: any FoodLogRepository, appState: AppState, logViewModel: LogViewModel,
         authViewModel: AuthViewModel, savedMealsViewModel: SavedMealsViewModel,
         healthProfileViewModel: HealthProfileViewModel, preferencesViewModel: PreferencesViewModel,
         onOpenQuickLog: @escaping () -> Void, onDeleteComplete: @escaping () -> Void,
         onLogComplete: @escaping (ReceiptPayload) -> Void, allowsMascotGreeting: Bool) {
        self.appState = appState
        self.logViewModel = logViewModel
        self.authViewModel = authViewModel
        self.savedMealsViewModel = savedMealsViewModel
        self.healthProfileViewModel = healthProfileViewModel
        self.preferencesViewModel = preferencesViewModel
        self.onOpenQuickLog = onOpenQuickLog
        self.onDeleteComplete = onDeleteComplete
        self.onLogComplete = onLogComplete
        self.allowsMascotGreeting = allowsMascotGreeting
        _copyPresentation = StateObject(wrappedValue: DayCopyReceiptViewModel(logs: logViewModel))
        _selection = StateObject(wrappedValue: LogScreenViewModel(logs: logViewModel,
            appState: appState, auth: authViewModel, savedMeals: savedMealsViewModel))
        _overviewModel = StateObject(wrappedValue: HomeOverviewViewModel(repository: repository,
            appState: appState, auth: authViewModel, logs: logViewModel, savedMeals: savedMealsViewModel,
            health: healthProfileViewModel, preferences: preferencesViewModel))
    }

    var body: some View {
        let timing = PerformanceSignposts.begin("UI.HomeBody")
        defer { PerformanceSignposts.end(timing) }
        return dataContent
    }

    private var diaryList: some View {
        List {
            overviewHeader
            mealSections
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        .refreshable {
            isPullRefreshing = true
            defer { isPullRefreshing = false }
            await refreshSummaries()
        }
        .matLoggTabBarScrollClearance()
        .overlay(alignment: .bottom) { receiptOverlay }
        .onDisappear {
            dismissDeletion()
            logViewModel.dismissCopyReceipt()
            mealReuseViewModel.dismissReceipt()
            selection.endSelection()
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private var receiptOverlay: some View {
        if !selection.isSelecting {
            Group {
                if let receipt = copyPresentation.receipt {
                    LogToastView(id: receipt.id, title: "Dagen fra i går er kopiert",
                        isUndoing: copyPresentation.isBusy,
                        onUndo: undoDayCopy,
                        onDismiss: { logViewModel.dismissCopyReceipt(id: receipt.id) })
                } else if let receipt = mealReuseViewModel.receipt {
                    LogToastView(id: receipt.id,
                        title: "\(receipt.title) lagt til i dag",
                        isUndoing: mealReuseViewModel.isSaving,
                        onUndo: {
                            Task {
                                if await mealReuseViewModel.undo() { await refreshAfterMealReuse() }
                            }
                        },
                        onDismiss: { mealReuseViewModel.dismissReceipt(id: receipt.id) })
                } else {
                    LogReceiptOverlay(logs: logViewModel, payload: nil, isUndoing: false,
                        onDeletionUndo: undoDeletion, onLoggingUndo: {}, onLoggingDismiss: {})
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, tabBarScrollMargin)
        }
    }

    private var navigationContent: some View {
        NavigationStack { diaryList }
        .preference(key: MatLoggDiarySelectionKey.self, value: diarySelectionPresentation)
        .sheet(item: $savedMealSource) { source in
            SaveMealFromLogsView(source: source) { selection.endSelection() }
        }
        .confirmationDialog("Slette \(selection.selectedLogIDs.count) registreringer?",
            isPresented: $showBatchDeletion, titleVisibility: .visible) {
            Button("Slett", role: .destructive) { deleteSelectedLogs() }
            Button("Avbryt", role: .cancel) {}
        }
        .onChange(of: selection.isSelecting) { _, active in
            if active {
                collapsedMeals = []
                dismissDeletion()
                logViewModel.dismissCopyReceipt()
                mealReuseViewModel.dismissReceipt()
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            selection.endSelection()
            collapsedMeals = []
            savedMealSource = nil
            dismissDeletion()
            appState.logSelectedDate = Date()
            await refreshSummaries()
        }
    }

    private var editingContent: some View {
        navigationContent
        .sheet(item: $editingLog) { log in logEditor(for: log) }
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
    }

    private var dataContent: some View {
        editingContent
        .onChange(of: productViewModel.metadataRevision) { _, _ in
            Task { await refreshSummaries() }
        }
        .onChange(of: logViewModel.mutationRevision) { _, _ in
            mealReuseViewModel.dismissReceipt()
            Task { await refreshSummaries() }
        }
        .onChange(of: savedMealsViewModel.receipt?.logIDs) { _, ids in
            if ids != nil {
                mealReuseViewModel.dismissReceipt()
                logViewModel.dismissCopyReceipt()
            }
        }
        .onChange(of: mealLogIDs) { previous, current in
            // Reveal newly logged, moved or restored entries without opening unrelated meals.
            for meal in current.keys where previous[meal] != current[meal] {
                collapsedMeals.remove(meal)
            }
        }
        .onChange(of: savedMealsViewModel.mutationRevision) { _, _ in
            Task { await refreshSummaries() }
        }
        .onChange(of: appState.logSelectedDate) { _, _ in
            collapsedMeals = []
            selection.endSelection()
            showBatchDeletion = false
            dismissDeletion()
            Task { await refreshSummaries() }
        }
    }

    private var diarySelectionPresentation: MatLoggDiarySelectionPresentation? {
        guard selection.isSelecting else { return nil }
        return MatLoggDiarySelectionPresentation(
            contextID: ObjectIdentifier(selection), count: selection.selectedLogIDs.count,
            canSave: selection.canSaveSelection, isBusy: selection.isDeletingOrRestoring,
            onSave: {
                savedMealSource = SavedMealCreationSource(mealType: selection.selectionMealType,
                    logs: selection.selectedLogs, allowsMealTypeChoice: selection.selectionSpansMeals)
            },
            onDelete: { showBatchDeletion = true })
    }

    private var mealLogIDs: [String: [UUID]] {
        overviewModel.overview.logsByMeal.mapValues { $0.map(\.id) }
    }

    private func logEditor(for log: FoodLog) -> some View {
        EditLogView(
            log: log,
            productName: productNames[log.productId] ?? "Ukjent matvare",
            brand: overviewModel.products[log.productId]?.brand,
            imageURL: overviewModel.products[log.productId]?.imageUrl.flatMap(URL.init(string:)),
            imageData: overviewModel.products[log.productId]?.localImageData,
            foodGroup: overviewModel.products[log.productId]?.foodGroup ?? .other,
            favorites: overviewModel.products[log.productId] == nil ? nil : productViewModel.favoriteRepository,
            onSave: { request in
                guard let userId = authViewModel.currentUser?.id else { return false }
                let success = await logViewModel.updateLog(log, amountG: request.amountG, mealType: request.mealType, userId: userId, portionSelection: request.portionSelection, clearPortion: request.portionSelection == nil)
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

    private var mealHeadingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout())
    }

    private var greetingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
    }

    private var overviewHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 4) {
                DayNavigationBar(selection: selectedDateBinding)
                if !Calendar.current.isDateInToday(selectedDate) {
                    Button {
                        selectedDateBinding.wrappedValue = Date()
                    } label: {
                        Text("I dag")
                            .font(AppTypography.secondaryEmphasis)
                            .foregroundStyle(AppColors.actionText)
                            .frame(minWidth: 72, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Gå til i dag")
                    .accessibilityIdentifier("home-go-to-today")
                    .frame(maxWidth: .infinity)
                }
            }
            .disabled(selection.isDeletingOrRestoring)

            HomeSyncBanner()

            if !preferencesViewModel.showGoalStatusOnHome, let error = overviewModel.errorMessage {
                ErrorMessageView(error).font(AppTypography.caption)
                Button("Prøv igjen") { Task { await refreshSummaries() } }
                    .frame(minHeight: 44)
            }
            if isSummaryLoading && !isPullRefreshing && (selectedSummary != nil || !preferencesViewModel.showGoalStatusOnHome) {
                ProgressView("Henter oversikt …")
            }


            greetingLayout {
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
                SporCompanionView(context: .home,
                    eligible: Calendar.current.isDateInToday(selectedDate) && allowsMascotGreeting,
                    isInteractive: true)
                    .frame(width: 72, height: 72)
            }

            DailyStatusCard(
                userId: authViewModel.currentUser?.id,
                date: selectedDate,
                showsEnergy: preferencesViewModel.showGoalStatusOnHome
            ) {
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

            LoggingDraftBanner(onLogComplete: onLogComplete)

            if mealReuseViewModel.draft == nil, let error = mealReuseViewModel.errorMessage {
                ErrorMessageView(error)
                    .font(AppTypography.body)
                    .accessibilityIdentifier("meal-reuse-error")
            }

            mealHeadingLayout {
                Text(mealsTitle)
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.ink)
                Spacer()
                diaryActions
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

        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .buttonStyle(.borderless)
        .listRowInsets(EdgeInsets())
        .listRowBackground(AppColors.background)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var mealSections: some View {
        let logsByMeal = overviewModel.overview.logsByMeal
        if selectedSummary != nil {
            ForEach(MealPresentation.all) { meal in
                MealOverviewCard(
                    meal: meal,
                    logs: logsByMeal[meal.key] ?? [],
                    totals: overviewModel.overview.mealTotals[meal.key] ?? NutritionCalculator.totals(for: []),
                    productName: { productNames[$0] ?? "Ukjent produkt" },
                    productImageURL: { overviewModel.products[$0]?.imageUrl.flatMap(URL.init(string:)) },
                    productImageData: { overviewModel.products[$0]?.localImageData },
                    productFoodGroup: { overviewModel.products[$0]?.foodGroup ?? .other },
                    isExpanded: !collapsedMeals.contains(meal.key) || selection.isSelecting,
                    isSelecting: selection.isSelecting,
                    selectedIDs: selection.selectedLogIDs,
                    allSelected: selection.isGroupSelected(meal.key),
                    onSelectGroup: { selection.toggleGroup(meal.key) },
                    showsEnergy: preferencesViewModel.showGoalStatusOnHome,
                    onToggle: { toggleMeal(meal.key) },
                    onSelect: { selection.toggleSelection($0.id) },
                    onEdit: { editingLog = $0 },
                    onDelete: deleteLog,
                    onAdd: {
                        collapsedMeals.remove(meal.key)
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
                .disabled(selection.isDeletingOrRestoring)
            }
        }
    }

    private var diaryActions: some View {
        HStack(spacing: 8) {
            Button(selection.isSelecting ? "Avbryt" : "Velg") {
                if selection.isSelecting { selection.endSelection() }
                else { selection.beginSelection() }
            }
            .accessibilityIdentifier("home-select")
            .frame(minWidth: 44, minHeight: 44)
            .disabled(selection.isDeletingOrRestoring || selection.isLoading || isSummaryLoading || selectedSummary?.logs.isEmpty != false)
            if selection.isSelecting {
                Button(selection.isGroupSelected() ? "Fjern alle valg" : "Velg alle") { selection.toggleGroup() }
                    .frame(minHeight: 44)
                    .disabled(selection.isDeletingOrRestoring)
            } else {
                Menu {
                    Menu("Lagre som måltid", systemImage: "square.stack.3d.up") {
                        ForEach(MealPresentation.all) { meal in
                            Button(meal.title) {
                                savedMealSource = SavedMealCreationSource(mealType: meal.key,
                                    logs: overviewModel.overview.logsByMeal[meal.key] ?? [])
                            }
                            .disabled(overviewModel.overview.logsByMeal[meal.key]?.isEmpty != false)
                        }
                    }
                    if Calendar.current.isDateInToday(selectedDate), !(logViewModel.yesterdaySummary?.logs.isEmpty ?? true) {
                        Button("Kopier hele dagen fra i går", systemImage: "doc.on.doc") {
                            Task { await copyYesterday() }
                        }
                        .disabled(copyPresentation.isBusy)
                    }
                } label: {
                    Image(systemName: "ellipsis").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Flere valg for dagsloggen")
                .accessibilityIdentifier("home-diary-menu")
                .disabled(isSummaryLoading || selection.isDeletingOrRestoring)
            }
        }
        .font(AppTypography.secondaryEmphasis)
        .foregroundStyle(AppColors.actionText)
        .buttonStyle(.borderless)
    }

    private func toggleMeal(_ meal: String) {
        guard !selection.isSelecting else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            if collapsedMeals.contains(meal) { collapsedMeals.remove(meal) }
            else { collapsedMeals.insert(meal) }
        }
    }

    private func deleteSelectedLogs() {
        let logs = selection.selectedLogs
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await logViewModel.deleteBatchWithUndo(logs, userId: userId) {
                selection.endSelection()
                onDeleteComplete()
                await appState.refreshSyncStatus()
            } else { appState.errorMessage = logViewModel.errorMessage }
            await refreshSummaries()
        }
    }

    private func undoDayCopy() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await logViewModel.undoDayCopy(userId: userId) {
                await appState.refreshSyncStatus()
            } else { appState.errorMessage = logViewModel.errorMessage }
            await refreshSummaries()
        }
    }

    private func copyYesterday() async {
        mealReuseViewModel.dismissReceipt()
        dismissDeletion()
        guard let userId = authViewModel.currentUser?.id,
              let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        if await logViewModel.copyLogs(from: yesterday, to: selectedDate, userId: userId) {
            await appState.refreshSyncStatus()
        } else { appState.errorMessage = logViewModel.errorMessage }
        await refreshSummaries()
    }

    private func dismissDeletion() {
        logViewModel.dismissDeletionReceipt()
    }

    private func deleteLog(_ log: FoodLog) {
        Task {
            guard let userId = authViewModel.currentUser?.id,
                  log.userId == userId,
                  Calendar.current.isDate(log.loggedDate, inSameDayAs: selectedDate),
                  !logViewModel.isDeletingOrRestoring else { return }
            logViewModel.dismissCopyReceipt()
            if await logViewModel.deleteWithUndo(log, userId: userId) {
                if logViewModel.deletionReceiptID != nil { onDeleteComplete() }
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage
            }
        }
    }

    private func undoDeletion() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await logViewModel.undoDeletion(userId: userId) {
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage
            }
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
        async let selectedLogs: Void = logViewModel.loadSelectedSummary(userId: userId, date: date)
        async let summary: Void = overviewModel.load(userId: userId, date: date)
        async let reuse: Void = loadMealReuse(userId: userId, date: date)
        _ = await (summary, reuse, selectedLogs)
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

private struct MealOverviewCard: View {
    let meal: MealPresentation
    let logs: [FoodLog]
    let totals: NutritionBreakdown
    let productName: (UUID) -> String
    var productImageURL: (UUID) -> URL? = { _ in nil }
    var productImageData: (UUID) -> Data? = { _ in nil }
    var productFoodGroup: (UUID) -> FoodGroup = { _ in .other }
    var isExpanded = true
    var isSelecting = false
    var selectedIDs: Set<UUID> = []
    var allSelected = false
    var onSelectGroup: () -> Void = {}
    var showsEnergy = true
    let onToggle: () -> Void
    var onSelect: (FoodLog) -> Void = { _ in }
    var onEdit: (FoodLog) -> Void = { _ in }
    let onDelete: (FoodLog) -> Void
    let onAdd: () -> Void
    var reuseSuggestion: MealReuseSuggestion? = nil
    var isReusing = false
    var onReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onAdjustReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onDismissReuse: () -> Void = {}

    var body: some View {
        Section {
            header
                .padding(.top, isCompact ? 12 : 16)
                .padding(.bottom, logs.isEmpty ? 16 : (isCompact ? 4 : 6))
                .listRowInsets(cardInsets)
                .listRowBackground(LogMealCardBackground(top: true, bottom: logs.isEmpty && reuseSuggestion == nil))
                .listRowSeparator(.hidden)

            if logs.isEmpty, reuseSuggestion != nil {
                emptyContent
                    .padding(.top, 6)
                    .padding(.bottom, 16)
                    .buttonStyle(.borderless)
                    .listRowInsets(cardInsets)
                    .listRowBackground(LogMealCardBackground(bottom: true))
                    .listRowSeparator(.hidden)
            } else if !logs.isEmpty && isExpanded {
                ForEach(logs) { log in
                    LogRowView(
                        log: log,
                        productName: productName(log.productId),
                        compact: true,
                        mealRoom: true,
                        showsMealNutrition: false,
                        imageURL: productImageURL(log.productId),
                        imageData: productImageData(log.productId),
                        foodGroup: productFoodGroup(log.productId),
                        isSelected: selectedIDs.contains(log.id),
                        onSelect: isSelecting ? { onSelect(log) } : nil,
                        onEdit: isSelecting ? nil : { onEdit(log) },
                        onMove: isSelecting ? nil : { onEdit(log) },
                        onDelete: isSelecting ? nil : { onDelete(log) }
                    )
                    .accessibilityIdentifier("home-log-row-\(log.id.uuidString)")
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(LogMealCardBackground())
                    .listRowSeparator(.hidden)
                }

            }

            if !logs.isEmpty {
                footer
                    .padding(.top, isCompact ? 4 : 6)
                    .padding(.bottom, isCompact ? 12 : 16)
                    .contentShape(Rectangle())

                    .listRowInsets(cardInsets)
                    .listRowBackground(LogMealCardBackground(bottom: true))
                    .listRowSeparator(.hidden)
            }

            Color.clear
                .frame(height: 16)
                .accessibilityHidden(true)
                .listRowInsets(EdgeInsets())
                .listRowBackground(AppColors.background)
                .listRowSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
    }

    private var isCompact: Bool { !isExpanded && !logs.isEmpty }

    private var registrationCount: String {
        logs.count == 1 ? "1 registrering" : "\(logs.count) registreringer"
    }

    private var cardInsets: EdgeInsets {
        EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: meal.icon)
                .font(AppTypography.secondaryEmphasis)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(AppColors.deepInk.opacity(0.8))
                .frame(width: 30, height: 30)
                .background(meal.tint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(meal.title)
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppColors.deepInk)
                        if !logs.isEmpty {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(AppTypography.captionEmphasis)
                        }
                    }
                    Text(logs.isEmpty ? "Ingen registreringer" : registrationCount)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(logs.isEmpty || isSelecting)
            .accessibilityLabel("\(meal.title), \(registrationCount)")
            .accessibilityValue(logs.isEmpty ? "Tomt" : (isExpanded ? "Utvidet" : "Sammenfoldet"))
            .accessibilityHint(logs.isEmpty || isSelecting ? "" : "Dobbelttrykk for å vise eller skjule matvarene")
            .accessibilityIdentifier("home-meal-open-\(meal.key)")
            Spacer()
            if isSelecting {
                Button(allSelected ? "Fjern valg" : "Velg alle", action: onSelectGroup)
                    .font(AppTypography.secondaryEmphasis)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(logs.isEmpty)
                    .accessibilityLabel("\(allSelected ? "Fjern valg" : "Velg alle") i \(meal.title)")
            } else {
                Button(action: onAdd) {
                    Text("+ Legg til")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundColor(AppColors.actionText)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-meal-add-\(meal.key)")
            }
        }
    }

    @ViewBuilder
    private var emptyContent: some View {
        if let suggestion = reuseSuggestion {
            MealReuseSuggestionView(
                suggestion: suggestion,
                isSaving: isReusing,
                onLog: { onReuse(suggestion) },
                onAdjust: { onAdjustReuse(suggestion) },
                onDismiss: onDismissReuse
            )
        } else {
            Text("Ikke logget ennå")
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 12) {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
                .accessibilityHidden(true)
            if showsEnergy {
                VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
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
                .accessibilityIdentifier("home-meal-nutrition-\(meal.key)")
            }
        }
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
        .environmentObject(FoodLoggingDraftViewModel(repository: database))
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
