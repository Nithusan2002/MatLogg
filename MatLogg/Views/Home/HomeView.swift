import SwiftUI
import AVFoundation
import UIKit

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var savedMealsViewModel: SavedMealsViewModel
    @State private var showScanCamera = false
    @State private var showManualAdd = false
    @State private var showRawMaterials = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var isUndoingSavedMeal = false
    @State private var showAddActions = false
    @State private var previousTab: AppTab = .home
    @State private var tabBarScrollMargin = MatLoggTabBar.defaultScrollContentBottomMargin
    
    var body: some View {
        TabView(selection: tabSelection) {
            HomeTabView(
                onOpenQuickLog: { showAddActions = true },
                onLogComplete: { payload in
                    Task { await loadTodaysSummary() }
                    receiptPayload = payload
                }
            )
                .tabItem {
                    Label("Hjem", systemImage: "house.fill")
                }
                .tag(AppTab.home)
                .matLoggSystemTabBarHidden()
            
            SearchHubView(
                onScan: { showScanCamera = true },
                onRawSearch: { showRawMaterials = true }
            )
                .tabItem {
                    Label("Søk", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)
                .matLoggSystemTabBarHidden()

            Color.clear
                .tabItem {
                    Label("Legg til", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.add)
                .matLoggSystemTabBarHidden()

            ProgressTabView()
                .tabItem {
                    Label("Oversikt", systemImage: "chart.bar")
                }
                .tag(AppTab.progress)
                .matLoggSystemTabBarHidden()

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
                .matLoggSystemTabBarHidden()
        }
        .environment(\.matLoggTabBarScrollMargin, tabBarScrollMargin)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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
            } else if let receipt = savedMealsViewModel.receipt {
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
        .fullScreenCover(isPresented: $showManualAdd) {
            ManualAddView(onOpenRawMaterials: {
                showManualAdd = false
                showRawMaterials = true
            })
            .environmentObject(appState)
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
        .onChange(of: appState.selectedTab) { _, newValue in
            if newValue != .add { previousTab = newValue }
        }
        .sheet(isPresented: $showAddActions) {
            QuickLogSheet(
                onSearch: {
                    showAddActions = false
                    showRawMaterials = true
                },
                onScan: {
                    showAddActions = false
                    showScanCamera = true
                },
                onManualAdd: {
                    showAddActions = false
                    showManualAdd = true
                },
                onLogComplete: { payload in
                    showAddActions = false
                    receiptPayload = payload
                    Task { await loadTodaysSummary() }
                },
                onSavedMealLogComplete: {
                    showAddActions = false
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
            get: { appState.selectedTab },
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
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate
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
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var mealReuseViewModel: MealReuseViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onOpenQuickLog: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    @EnvironmentObject var waterViewModel: WaterViewModel
    @State private var selectedSummary: DailySummary?
    @State private var productNames: [UUID: String] = [:]
    @State private var quickProducts: [Product] = []
    @State private var selectedProduct: Product?
    @State private var selectedMealForLog: MealPresentation?
    @State private var isSummaryLoading = true
    
    var body: some View {
        let logsByMeal = selectedSummary?.logsByMeal ?? [:]

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    homeHeader

                    DayNavigationBar(selection: selectedDateBinding)

                    if appState.unsyncedSyncCount > 0 {
                        Label(
                            homeSyncStatusText,
                            systemImage: appState.isSyncAvailable ? "arrow.triangle.2.circlepath" : "internaldrive"
                        )
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel(homeSyncStatusText)
                    }

                    if preferencesViewModel.showGoalStatusOnHome {
                        if isSummaryLoading {
                            CardContainer {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Henter oversikt …")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                            }
                            .accessibilityElement(children: .combine)
                        } else if let summary = selectedSummary, let goal = healthProfileViewModel.currentGoal {
                            StatusCardView(
                                summary: summary,
                                goal: goal
                            )
                        } else {
                            CardContainer {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Oversikten er ikke klar", systemImage: "chart.bar")
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                    Text("Du kan fortsatt loggføre mat. Sett opp et mål i profilen for å se fremgangen her.")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    WaterCardView(viewModel: waterViewModel, userId: authViewModel.currentUser?.id, date: appState.logSelectedDate)

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
                        Text(error)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .accessibilityIdentifier("meal-reuse-error")
                    }

                    HStack {
                        Text(mealsTitle)
                            .font(AppTypography.sectionTitle)
                            .foregroundColor(AppColors.ink)
                        Spacer()
                        Text(loggedMealCountLabel)
                            .font(AppTypography.captionEmphasis)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    ForEach(MealPresentation.all) { meal in
                        MealOverviewCard(
                            meal: meal,
                            logs: logsByMeal[meal.key] ?? [],
                            productName: { productNames[$0] ?? "Ukjent produkt" },
                            onOpen: { selectedMealForLog = meal },
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

                    quickLogSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .matLoggTabBarScrollClearance()
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedMealForLog) { meal in
                LoggView(initialDate: selectedDate, initialMealFilter: meal.key)
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            appState.logSelectedDate = Date()
            await refreshSummaries()
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
        .onChange(of: appState.logSelectedDate) { _, _ in
            Task { await refreshSummaries() }
        }
        
    }

    private var homeSyncStatusText: String {
        let count = appState.unsyncedSyncCount
        let noun = count == 1 ? "endring" : "endringer"
        if !appState.isSyncAvailable {
            return "\(count) \(noun) lagret bare på denne enheten"
        }
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
    
    private func refreshAfterMealReuse() async {
        if let userId = authViewModel.currentUser?.id {
            await logViewModel.loadTodaysSummary(userId: userId)
        }
        await appState.refreshSyncStatus()
        await refreshSummaries()
    }

    private func refreshSummaries() async {
        await loadSelectedSummary()
        if let userId = authViewModel.currentUser?.id {
            let scans = await productViewModel.recentScans(userId: userId, limit: 6)
            let productsByID = await productViewModel.products(ids: Set(scans.map(\.productId)))
            var seen = Set<UUID>()
            quickProducts = scans.compactMap { scan in
                guard seen.insert(scan.productId).inserted else { return nil }
                return productsByID[scan.productId]
            }
            await mealReuseViewModel.load(userId: userId, date: selectedDate)
        }
    }
    
    private func loadSelectedSummary() async {
        let requestedDate = selectedDate
        isSummaryLoading = true
        guard let userId = authViewModel.currentUser?.id else {
            selectedSummary = nil
            productNames = [:]
            isSummaryLoading = false
            return
        }
        let summary = await logViewModel.fetchSummary(userId: userId, date: requestedDate)
        let names = await logViewModel.productNames(for: summary.logs)
        guard Calendar.current.isDate(requestedDate, inSameDayAs: selectedDate) else { return }
        selectedSummary = summary
        productNames = names
        isSummaryLoading = false
    }

    private var loggedMealCount: Int {
        Set(selectedSummary?.logs.map(\.mealType) ?? []).count
    }

    private var loggedMealCountLabel: String {
        loggedMealCount == 0 ? "Ingen logget ennå" : "\(loggedMealCount) av 4 logget"
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

    @ViewBuilder
    private var quickLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loggfør på ett trykk")
                .font(AppTypography.title)
                .foregroundColor(AppColors.deepInk)

            if quickProducts.isEmpty {
                Text("Favoritter og nylig brukte matvarer dukker opp her.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(quickProducts.prefix(6)) { product in
                            Button {
                                selectedProduct = product
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
    }

    private var homeHeader: some View {
        HStack(spacing: 10) {
            Text("MatLogg")
                .font(AppTypography.title)
                .foregroundColor(AppColors.action)
            Spacer()
            Button {
                appState.selectedTab = .profile
            } label: {
                Text(profileInitials)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.background)
                    .frame(width: 44, height: 44)
                    .background(AppColors.deepInk, in: Circle())
            }
            .accessibilityLabel("Åpne profil")
        }
    }

    private var profileInitials: String {
        guard let user = authViewModel.currentUser else { return "ML" }
        return String(user.firstName.prefix(1) + user.lastName.prefix(1)).uppercased()
    }

    private var shortDateLabel: String {
        selectedDate.formatted(
            .dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO"))
        )
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
    let productName: (UUID) -> String
    let onOpen: () -> Void
    let onAdd: () -> Void
    var reuseSuggestion: MealReuseSuggestion? = nil
    var isReusing = false
    var onReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onAdjustReuse: (MealReuseSuggestion) -> Void = { _ in }
    var onDismissReuse: () -> Void = {}

    var body: some View {
        let totals = NutritionCalculator.totals(for: logs)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(String(meal.title.prefix(1)))
                    .font(AppTypography.captionEmphasis)
                    .foregroundColor(AppColors.deepInk)
                    .frame(width: 34, height: 34)
                    .background(meal.tint.opacity(0.22), in: Circle())
                Text(meal.title.uppercased())
                    .font(AppTypography.captionEmphasis)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Button(action: onAdd) {
                    Text("+ Legg til")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.action)
                        .frame(minWidth: 44, minHeight: 44)
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
                Text("\(meal.title) · ikke logget ennå")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(logs.prefix(3)) { log in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(productName(log.productId).prefix(1)).uppercased())
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(AppColors.mutedSurface, in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(productName(log.productId))
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.deepInk)
                                Text("\(Int(log.amountG)) \(log.resolvedAmountUnit.rawValue)")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    if logs.count > 3 {
                        Text("+ \(logs.count - 3) flere")
                            .font(AppTypography.captionEmphasis).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
                    .accessibilityHidden(true)

                Text("\(NutritionDisplay.wholeCalories(totals.calories)) kcal · P \(NutritionDisplay.wholeGrams(totals.protein)) g · K \(NutritionDisplay.wholeGrams(totals.carbs)) g · F \(NutritionDisplay.wholeGrams(totals.fat)) g")
                    .font(AppTypography.captionEmphasis)
                    .foregroundColor(AppColors.deepInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Totalt for \(meal.title): \(NutritionDisplay.wholeCalories(totals.calories)) kilokalorier, proteiner \(NutritionDisplay.wholeGrams(totals.protein)) gram, karbohydrater \(NutritionDisplay.wholeGrams(totals.carbs)) gram, fett \(NutritionDisplay.wholeGrams(totals.fat)) gram")
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if logs.isEmpty {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            }
        }
        .shadow(color: logs.isEmpty ? .clear : AppColors.deepInk.opacity(0.06), radius: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            if !logs.isEmpty { onOpen() }
        }
        .accessibilityElement(children: .contain)
        .accessibilityHint(logs.isEmpty ? "Bruk Legg til-knappen for å logge mat" : "Åpner alle innslag med redigering")
    }

}

struct StatusCardView: View {
    let summary: DailySummary
    let goal: Goal

    private var calorieBalance: CalorieBalance? {
        GoalCalculator.calorieBalance(dailyGoal: goal.dailyCalories, consumed: summary.totalCalories)
    }
    
    var remainingCalories: Int {
        calorieBalance?.remaining ?? 0
    }
    
    var overCalories: Int {
        calorieBalance?.over ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(AppColors.calorieBlue)
                                .frame(width: 8, height: 8)
                                .accessibilityHidden(true)
                            Text("KALORIER SPIST")
                                .font(AppTypography.captionEmphasis)
                        }
                        Text("\(NutritionDisplay.wholeCalories(summary.totalCalories))")
                            .font(AppTypography.hero)
                        Text(overCalories > 0 ? "\(overCalories) kcal over mål" : "\(remainingCalories) kcal igjen av \(goal.dailyCalories)")
                            .font(AppTypography.bodyEmphasis)
                    }
                    .foregroundColor(AppColors.deepInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    Rectangle()
                        .fill(AppColors.separator)
                        .frame(height: 1)
                        .accessibilityHidden(true)

                    VStack(spacing: 12) {
                        ProgressRow(
                            label: "Proteiner",
                            valueText: "\(NutritionDisplay.wholeGrams(summary.totalProtein))g / \(NutritionDisplay.wholeGrams(goal.proteinTargetG))g",
                            progress: progressValue(current: Double(summary.totalProtein), target: Double(goal.proteinTargetG)),
                            tint: AppColors.macroProteinTint
                        )
                        ProgressRow(
                            label: "Karbohydrater",
                            valueText: "\(NutritionDisplay.wholeGrams(summary.totalCarbs))g / \(NutritionDisplay.wholeGrams(goal.carbsTargetG))g",
                            progress: progressValue(current: Double(summary.totalCarbs), target: Double(goal.carbsTargetG)),
                            tint: AppColors.macroCarbTint
                        )
                        ProgressRow(
                            label: "Fett",
                            valueText: "\(NutritionDisplay.wholeGrams(summary.totalFat))g / \(NutritionDisplay.wholeGrams(goal.fatTargetG))g",
                            progress: progressValue(current: Double(summary.totalFat), target: Double(goal.fatTargetG)),
                            tint: AppColors.macroFatTint
                        )
                    }
                }
            }
        }
    }

    private func progressValue(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return current / target
    }
}

struct MealTypeSelector: View {
    @EnvironmentObject var appState: AppState
    
    let mealTypes = ["Frokost", "Lunsj", "Middag", "Snacks"]
    let mealTypeKeys = ["frokost", "lunsj", "middag", "snacks"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<mealTypes.count, id: \.self) { index in
                MealChip(
                    title: mealTypes[index],
                    isSelected: appState.selectedMealType == mealTypeKeys[index],
                    action: { appState.selectedMealType = mealTypeKeys[index] }
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
    @State private var recentScans: [ScanHistory] = []
    @State private var productsByID: [UUID: Product] = [:]
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
                
                if recentScans.isEmpty {
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
        .task {
            if let userId = authViewModel.currentUser?.id {
                let scans = await productViewModel.recentScans(userId: userId)
                recentScans = scans
                productsByID = await productViewModel.products(ids: Set(scans.map(\.productId)))
            }
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
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate
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
    let onLogComplete: (ReceiptPayload) -> Void
    let onSearch: () -> Void

    @StateObject private var cameraAuthorization: CameraAuthorizationViewModel
    
    @State private var scannedBarcode: String?
    @State private var scannedProduct: Product?
    @State private var isLoading = false
    @State private var isTorchOn = false
    @State private var isTorchAvailable = false
    @State private var scanHelpTitle: String?
    @State private var scanHelpHints: [String] = []
    @State private var showScanHelp = false
    @State private var showProductDetail = false
    @State private var showProductNotFound = false
    @State private var showManualProduct = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false

    init(
        onLogComplete: @escaping (ReceiptPayload) -> Void,
        onSearch: @escaping () -> Void = {},
        authorizationProvider: any CameraAuthorizationProviding = CameraAuthorizationService()
    ) {
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
                .background(Color.black)
                .ignoresSafeArea()

            if cameraAuthorization.state == .authorized {
                ScannerFocusOverlay(isLoading: isLoading)
                    .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [Color.black.opacity(0.58), Color.black.opacity(0)],
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
            scannedBarcode = nil
            scannedProduct = nil
            isLoading = false
        }) {
            if let product = scannedProduct {
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
                scannedProduct = product
                if let userId = authViewModel.currentUser?.id {
                    Task {
                        await productViewModel.recordScan(productId: product.id, userId: userId)
                        await appState.refreshSyncStatus()
                    }
                }
            }
        }
        .alert("Produktet kan ikke brukes ennå", isPresented: $showProductNotFound) {
            Button("Legg til selv", action: {
                showManualProduct = true
            })
            Button("Avbryt", role: .cancel) {
                scannedBarcode = nil
            }
        } message: {
            Text("Vi fant ikke komplette næringsverdier per 100 g eller 100 ml. Vil du legge produktet til manuelt?")
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
            if showScanHelp, let scanHelpTitle {
                VStack(spacing: 6) {
                    Text(scanHelpTitle)
                        .font(AppTypography.bodyEmphasis)
                    ForEach(Array(scanHelpHints.enumerated()), id: \.offset) { _, hint in
                        Text(hint)
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)
            }

            VStack(spacing: 10) {
                ScannerActionButton(title: "Søk etter vare", systemImage: "magnifyingglass") {
                    openSearch()
                }
                ScannerActionButton(title: "Registrer manuelt", systemImage: "square.and.pencil") {
                    scannedBarcode = nil
                    showManualProduct = true
                }
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.55 : 1)
        }
    }

    private var cameraAuthorizationProgress: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text(cameraAuthorization.state == .requesting ? "Venter på kameratilgang …" : "Sjekker kameratilgang …")
                .font(AppTypography.body)
                .foregroundColor(.white.opacity(0.85))
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
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            if let primaryTitle {
                PrimaryButton(
                    title: primaryTitle,
                    systemImage: primarySystemImage,
                    action: primaryAction
                )
            }

            Button("Registrer manuelt") {
                scannedBarcode = nil
                showManualProduct = true
            }
            .font(AppTypography.bodyEmphasis)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1)
            )

            Button("Velg en annen metode") { dismiss() }
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(.white)
                .frame(minHeight: 44)
                .accessibilityHint("Lukker kameraet og går tilbake til de andre måtene å legge til mat på")
        }
        .foregroundColor(.white)
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
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onSearch()
        }
    }
    
    private func handleBarcodeDetected(_ scannedCode: ScannedBarcode) {
        guard !isLoading else { return }

        let barcode: String
        do {
            barcode = try productViewModel.lookupBarcode(from: scannedCode)
        } catch {
            presentScanHelp(
                title: "Denne koden inneholder ikke et gyldig produktnummer",
                hints: ["Prøv en annen kode på pakken", "Du kan også søke eller registrere produktet manuelt"]
            )
            return
        }

        guard scannedBarcode != barcode else { return }
        
        scannedBarcode = barcode
        isLoading = true

        UIAccessibility.post(
            notification: .announcement,
            argument: "Kode funnet. Henter produkt."
        )

        HapticFeedbackService.shared.trigger(.barcodeDetected, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.barcodeDetected, isEnabled: preferencesViewModel.soundFeedbackEnabled)
        
        if let cached = productViewModel.cachedProduct(
            barcode: barcode,
            ownerUserId: authViewModel.currentUser?.id
        ) {
            scannedProduct = cached
            isLoading = false
            showProductDetail = true
            Task {
                await recordCachedScan(cached)
                if let refreshed = await productViewModel.refreshCachedProductIfNeeded(cached),
                   scannedBarcode == barcode {
                    scannedProduct = refreshed
                }
            }
            return
        }
        
        Task {
            do {
                let product = try await productViewModel.fetchProduct(barcode: barcode)
                await MainActor.run {
                    scannedProduct = product
                    isLoading = false
                    showScanHelp = false
                    showProductDetail = true
                }
                await saveScannedProduct(product)
            } catch let apiError as APIService.APIError {
                await MainActor.run {
                    isLoading = false
                    switch apiError {
                    case .serverError(404), .incompleteProductData:
                        showProductNotFound = true
                    case .backendError(let statusCode, _, _) where statusCode == 404:
                        showProductNotFound = true
                    case .rateLimited:
                        presentScanHelp(
                            title: apiError.localizedDescription,
                            hints: ["Vent litt", "Prøv deretter å skanne på nytt"]
                        )
                    case .serverError(let statusCode) where (500...599).contains(statusCode):
                        presentScanHelp(
                            title: "Produktdatabasen er midlertidig utilgjengelig",
                            hints: ["Prøv igjen litt senere", "Legg til produktet manuelt om nødvendig"]
                        )
                    default:
                        HapticFeedbackService.shared.trigger(
                            .error,
                            isEnabled: preferencesViewModel.hapticsFeedbackEnabled
                        )
                        SoundFeedbackService.shared.play(
                            .error,
                            isEnabled: preferencesViewModel.soundFeedbackEnabled
                        )
                        presentScanHelp(
                            title: "Fikk ikke kontakt med produktdatabasen",
                            hints: ["Sjekk nett", "Prøv igjen", "Hold kamera rolig og skann på nytt"]
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    HapticFeedbackService.shared.trigger(
                        .error,
                        isEnabled: preferencesViewModel.hapticsFeedbackEnabled
                    )
                    SoundFeedbackService.shared.play(
                        .error,
                        isEnabled: preferencesViewModel.soundFeedbackEnabled
                    )
                    presentScanHelp(
                        title: "Noe gikk galt ved skanning",
                        hints: ["Hold kamera rolig", "Mer lys", "Flytt nærmere strekkoden"]
                    )
                }
            }
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
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate
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

    private func saveScannedProduct(_ product: Product) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        if await productViewModel.saveScannedProduct(product, userId: userId) {
            await appState.refreshSyncStatus()
        } else {
            appState.errorMessage = productViewModel.errorMessage
        }
    }

    private func recordCachedScan(_ product: Product) async {
        guard let userId = authViewModel.currentUser?.id else { return }
        if await productViewModel.recordScan(productId: product.id, userId: userId) {
            await appState.refreshSyncStatus()
        } else {
            appState.errorMessage = productViewModel.errorMessage
        }
    }
    
    private func handleError(_ error: String) {
        presentScanHelp(
            title: error,
            hints: ["Hold kamera rolig", "Mer lys", "Flytt nærmere strekkoden"]
        )
        HapticFeedbackService.shared.trigger(.error, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.error, isEnabled: preferencesViewModel.soundFeedbackEnabled)
    }

    private func handleCameraUnavailable() {
        isTorchOn = false
        isTorchAvailable = false
        cameraAuthorization.reportCameraUnavailable()
    }
    
    private func presentScanHelp(title: String, hints: [String]) {
        scanHelpTitle = title
        scanHelpHints = hints
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
                        .foregroundColor(AppColors.action)
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
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    let onScan: () -> Void
    let onRawSearch: () -> Void
    @State private var recentScans: [ScanHistory] = []
    @State private var productsByID: [UUID: Product] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Finn maten din")
                            .font(AppTypography.hero)
                            .foregroundColor(AppColors.ink)
                        Text("Søk, skann eller bruk noe du har logget før.")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    QuickSearchBar(onSearch: onRawSearch, onScan: onScan)

                    Text("Snarveier")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.ink)

                    HStack(spacing: 12) {
                        SearchShortcut(title: "Råvarer", icon: "leaf.fill", tint: AppColors.success, action: onRawSearch)
                        SearchShortcut(title: "Skann", icon: "barcode.viewfinder", tint: AppColors.accent, action: onScan)
                    }

                    Text("Nylig brukt")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.ink)

                    if recentScans.isEmpty {
                        CardContainer {
                            Label("Ingen nylige produkter ennå", systemImage: "clock")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        }
                    } else {
                        ForEach(recentScans.prefix(6)) { scan in
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(AppColors.deepInk)
                                    .frame(width: 44, height: 44)
                                    .background(AppColors.info.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading) {
                                    Text(productsByID[scan.productId]?.name ?? "Ukjent produkt")
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.ink)
                                    Text(scan.scannedAt.timeAgoDisplay())
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    Text("Favoritter")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.ink)
                    CardContainer {
                        Label("Favoritter du lagrer vises her", systemImage: "star")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .matLoggTabBarScrollClearance()
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if let userId = authViewModel.currentUser?.id {
                    let scans = await productViewModel.recentScans(userId: userId, limit: 6)
                    recentScans = scans
                    productsByID = await productViewModel.products(ids: Set(scans.map(\.productId)))
                }
            }
        }
    }
}

private struct SearchShortcut: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon).font(.title2).foregroundColor(AppColors.ink)
                Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .padding(14)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let database = DatabaseService()
    HomeView()
        .environmentObject(AppState(databaseService: database))
        .environmentObject(LogViewModel(repository: database))
        .environmentObject(MealReuseViewModel(repository: database))
        .environmentObject(SavedMealsViewModel(savedMealRepository: database, foodLogRepository: database))
        .environmentObject(ProductViewModel(repository: database))
        .environmentObject(HealthProfileViewModel(repository: database))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
        .environmentObject(WaterViewModel(repository: database))
        .environmentObject(UserDataExportService(logRepository: database, savedMealRepository: database, waterRepository: database))
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

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .frame(width: 300, height: 180)
                                .offset(y: -42)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }

            VStack(spacing: 32) {
                ScannerCornerFrame()
                    .stroke(
                        isLoading ? AppColors.success : Color.white,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 300, height: 180)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Henter produkt …")
                            .font(AppTypography.bodyEmphasis)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.68), in: Capsule())
                    .accessibilityElement(children: .combine)
                } else {
                    VStack(spacing: 4) {
                        Text("Plasser koden i rammen")
                            .font(AppTypography.bodyEmphasis)
                        Text("Strekkode eller Data Matrix")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color.white.opacity(0.82))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .foregroundStyle(Color.white)
            .offset(y: -12)
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
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(
                    isSelected ? AppColors.action.opacity(0.9) : Color.black.opacity(0.58),
                    in: Circle()
                )
                .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 1))
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
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .background(Color.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
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
