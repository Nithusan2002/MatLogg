import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showScanCamera = false
    @State private var showManualAdd = false
    @State private var showRawMaterials = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var repeatProduct: Product?
    @State private var showAddActions = false
    @State private var previousTab: AppTab = .home
    
    var body: some View {
        TabView(selection: tabSelection) {
            HomeTabView(
                showScanCamera: $showScanCamera,
                showManualAdd: $showManualAdd,
                showRawMaterials: $showRawMaterials,
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
            
            SearchHubView(
                onScan: { showScanCamera = true },
                onRawSearch: { showRawMaterials = true }
            )
                .tabItem {
                    Label("Søk", systemImage: "magnifyingglass")
                }
                .tag(AppTab.search)

            Color.clear
                .tabItem {
                    Label("Legg til", systemImage: "plus.circle.fill")
                }
                .tag(AppTab.add)

            ProgressTabView()
                .tabItem {
                    Label("Tall", systemImage: "chart.bar")
                }
                .tag(AppTab.progress)

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MatLoggTabBar(selection: tabSelection)
        }
        .environmentObject(appState)
        .sheet(isPresented: $showScanCamera) {
            CameraView(onLogComplete: { payload in
                Task {
                    await loadTodaysSummary()
                }
                showScanCamera = false
                receiptPayload = payload
            })
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
        .sheet(item: $receiptPayload) { payload in
            ReceiptView(
                product: payload.product,
                amountG: payload.amountG,
                nutrition: payload.nutrition,
                mealType: payload.mealType
            ) { action in
                switch action {
                case .scanNext: showScanCamera = true
                case .addAgain:
                    appState.selectedMealType = payload.mealType
                    repeatProduct = payload.product
                case .close: break
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(item: $repeatProduct) { product in
            ProductDetailView(product: product, appState: appState) { payload in
                receiptPayload = payload
            }
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
}

struct HomeTabView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var healthProfileViewModel: HealthProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    @Binding var showScanCamera: Bool
    @Binding var showManualAdd: Bool
    @Binding var showRawMaterials: Bool
    let onOpenQuickLog: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var recentScans: [ScanHistory] = []
    @State private var selectedProduct: Product?
    @State private var selectedMealForLog: MealPresentation?
    @State private var isSummaryLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    homeHeader

                    if appState.pendingSyncCount > 0 {
                        Label(
                            "\(appState.pendingSyncCount) \(appState.pendingSyncCount == 1 ? "endring" : "endringer") lagret på enheten og venter på synk",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityLabel("Endringer lagret på enheten. Venter på synk.")
                    }

                    if preferencesViewModel.showGoalStatusOnHome {
                        if isSummaryLoading {
                            CardContainer {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Henter dagens oversikt …")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                            }
                            .accessibilityElement(children: .combine)
                        } else if let summary = selectedSummary, let goal = healthProfileViewModel.currentGoal {
                            StatusCardView(
                                summary: summary,
                                goal: goal,
                                dayLabel: "Dagens matinntak",
                                hideGoals: preferencesViewModel.safeModeHideGoals,
                                hideCalories: preferencesViewModel.safeModeHideCalories
                            )
                        } else {
                            CardContainer {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Dagens oversikt er ikke klar", systemImage: "chart.bar")
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

                    QuickSearchBar(
                        onSearch: { showRawMaterials = true },
                        onScan: { showScanCamera = true }
                    )

                    HStack {
                        Text("Måltider i dag")
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
                            logs: selectedSummary?.logs.filter { $0.mealType == meal.key } ?? [],
                            hideCalories: preferencesViewModel.safeModeHideCalories,
                            productName: { productViewModel.product(id: $0)?.name ?? "Ukjent produkt" },
                            onOpen: { selectedMealForLog = meal },
                            onAdd: {
                                appState.selectedMealType = meal.key
                                onOpenQuickLog()
                            }
                        )
                    }

                    quickLogSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedMealForLog) { meal in
                LoggView(initialDate: selectedDate, initialMealFilter: meal.key)
            }
        }
        .task {
            await refreshSummaries()
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
        .onChange(of: logViewModel.todaysSummary.logs.count) { _, _ in
            Task { await loadSelectedSummary() }
        }
        
    }
    
    private func refreshSummaries() async {
        selectedDate = Date()
        await loadSelectedSummary()
        if let userId = authViewModel.currentUser?.id {
            recentScans = await productViewModel.recentScans(userId: userId, limit: 6)
        }
    }
    
    private func loadSelectedSummary() async {
        isSummaryLoading = true
        defer { isSummaryLoading = false }
        guard let userId = authViewModel.currentUser?.id else {
            selectedSummary = nil
            return
        }
        selectedSummary = await logViewModel.fetchSummary(userId: userId, date: selectedDate)
    }

    private var loggedMealCount: Int {
        Set(selectedSummary?.logs.map(\.mealType) ?? []).count
    }

    private var loggedMealCountLabel: String {
        loggedMealCount == 0 ? "Ingen logget ennå" : "\(loggedMealCount) av 4 logget"
    }

    private var quickProducts: [Product] {
        var seen = Set<UUID>()
        return recentScans.compactMap { scan in
            guard seen.insert(scan.productId).inserted else { return nil }
            return productViewModel.product(id: scan.productId)
        }
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
                                    Text("\(product.caloriesPer100g) kcal per 100 g")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(width: 132, alignment: .leading)
                                .frame(minHeight: 76, alignment: .leading)
                                .padding(14)
                                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
                    .foregroundColor(.white)
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

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "EEEE d. MMMM"
        return formatter.string(from: selectedDate).capitalized
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
                    .foregroundColor(.white)
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
    let hideCalories: Bool
    let productName: (UUID) -> String
    let onOpen: () -> Void
    let onAdd: () -> Void

    private var totalCalories: Int { logs.reduce(0) { $0 + $1.calories } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }

            if logs.isEmpty {
                Text("\(meal.title) · ikke logget ennå")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
            } else {
                VStack(spacing: 14) {
                    ForEach(logs.prefix(3)) { log in
                        HStack(alignment: .top, spacing: 12) {
                            Text(String(productName(log.productId).prefix(1)).uppercased())
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 54, height: 54)
                                .background(AppColors.mutedSurface, in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(productName(log.productId))
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                        .lineLimit(1)
                                    Spacer()
                                    if !hideCalories {
                                        Text("\(log.calories)")
                                            .font(AppTypography.title)
                                            .foregroundColor(AppColors.deepInk)
                                    }
                                }
                                Text("\(Int(log.amountG)) g")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                HStack(spacing: 6) {
                                    macroTag("P \(Int(log.proteinG)) g", color: AppColors.macroProteinTint)
                                    macroTag("K \(Int(log.carbsG)) g", color: AppColors.macroCarbTint)
                                    macroTag("F \(Int(log.fatG)) g", color: AppColors.macroFatTint)
                                }
                                Text(log.loggedTime.formatted(date: .omitted, time: .shortened))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    if logs.count > 3 {
                        Text("+ \(logs.count - 3) flere")
                            .font(AppTypography.captionEmphasis).foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            if logs.isEmpty {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(AppColors.controlBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            }
        }
        .shadow(color: logs.isEmpty ? .clear : AppColors.deepInk.opacity(0.06), radius: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 30))
        .onTapGesture {
            if !logs.isEmpty { onOpen() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(logs.isEmpty ? "Bruk Legg til-knappen for å logge mat" : "Åpner alle innslag med redigering")
    }

    private func macroTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(AppTypography.captionEmphasis)
            .foregroundColor(AppColors.deepInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct StatusCardView: View {
    let summary: DailySummary
    let goal: Goal
    let dayLabel: String
    let hideGoals: Bool
    let hideCalories: Bool
    
    var remainingCalories: Int {
        max(0, goal.dailyCalories - summary.totalCalories)
    }
    
    var overCalories: Int {
        max(0, summary.totalCalories - goal.dailyCalories)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayLabel)
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.deepInk)
                Spacer()
                Text(statusDateLabel)
                    .font(AppTypography.captionEmphasis)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            if !hideCalories {
                VStack(alignment: .leading, spacing: 5) {
                    Text("KALORIER SPIST")
                        .font(AppTypography.captionEmphasis)
                    Text("\(summary.totalCalories)")
                        .font(AppTypography.display)
                    if !hideGoals {
                        Text(overCalories > 0 ? "\(overCalories) kcal over mål" : "\(remainingCalories) kcal igjen av \(goal.dailyCalories)")
                            .font(AppTypography.bodyEmphasis)
                    }
                }
                .foregroundColor(AppColors.deepInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(AppColors.calorieBlue, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
                .shadow(color: AppColors.deepInk.opacity(0.12), radius: 0, y: 4)
            }

            if !hideGoals {
                VStack(spacing: 12) {
                        ProgressRow(
                            label: "Proteiner",
                            valueText: "\(Int(summary.totalProtein))g / \(Int(goal.proteinTargetG))g",
                            progress: progressValue(current: Double(summary.totalProtein), target: Double(goal.proteinTargetG)),
                            tint: AppColors.macroProteinTint
                        )
                        ProgressRow(
                            label: "Karbohydrater",
                            valueText: "\(Int(summary.totalCarbs))g / \(Int(goal.carbsTargetG))g",
                            progress: progressValue(current: Double(summary.totalCarbs), target: Double(goal.carbsTargetG)),
                            tint: AppColors.macroCarbTint
                        )
                        ProgressRow(
                            label: "Fett",
                            valueText: "\(Int(summary.totalFat))g / \(Int(goal.fatTargetG))g",
                            progress: progressValue(current: Double(summary.totalFat), target: Double(goal.fatTargetG)),
                            tint: AppColors.macroFatTint
                        )
                }
                .padding(16)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: AppColors.deepInk.opacity(0.06), radius: 0, y: 4)
            }
        }
    }

    private var statusDateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "EEEE d. MMMM"
        return formatter.string(from: summary.date).uppercased()
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
    let nutrition: NutritionBreakdown
    let mealType: String
}

enum ReceiptAction {
    case scanNext
    case addAgain
    case close
}

struct ScanButtonLarge: View {
    let action: () -> Void
    
    var body: some View {
        PrimaryButton(title: "Skann", systemImage: "barcode.viewfinder", height: 72, action: action)
    }
}

struct ScanHistoryView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var recentScans: [ScanHistory] = []
    @State private var selectedProduct: Product?
    @State private var showMissingProductAlert = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var repeatProduct: Product?
    @State private var showScanCamera = false
    
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
                            if let product = productViewModel.product(id: scan.productId) {
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
        .task {
            if let userId = authViewModel.currentUser?.id {
                recentScans = await productViewModel.recentScans(userId: userId)
            }
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product, appState: appState) { payload in
                receiptPayload = payload
            }
        }
        .sheet(item: $receiptPayload) { payload in
            ReceiptView(
                product: payload.product,
                amountG: payload.amountG,
                nutrition: payload.nutrition,
                mealType: payload.mealType,
                onAction: { action in
                    switch action {
                    case .scanNext:
                        showScanCamera = true
                    case .addAgain:
                        appState.selectedMealType = payload.mealType
                        repeatProduct = payload.product
                    case .close:
                        break
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(item: $repeatProduct) { product in
            ProductDetailView(product: product, appState: appState) { payload in
                receiptPayload = payload
            }
        }
        .fullScreenCover(isPresented: $showScanCamera) {
            CameraView { payload in
                showScanCamera = false
                receiptPayload = payload
            }
        }
        .alert("Produkt ikke tilgjengelig", isPresented: $showMissingProductAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Vi finner ikke produktdata lokalt. Prøv å skanne på nytt.")
        }
    }
    
    private func productName(for scan: ScanHistory) -> String {
        productViewModel.product(id: scan.productId)?.name ?? "Ukjent produkt"
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onLogComplete: (ReceiptPayload) -> Void
    
    @State private var scannedBarcode: String?
    @State private var scannedProduct: Product?
    @State private var isLoading = false
    @State private var isTorchOn = false
    @State private var scanHelpTitle: String?
    @State private var scanHelpHints: [String] = []
    @State private var showScanHelp = false
    @State private var showProductDetail = false
    @State private var showProductNotFound = false
    @State private var showManualProduct = false
    @State private var showCameraPrePrompt = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Avbryt") { dismiss() }
                    Spacer()
                    Button(action: { isTorchOn.toggle() }) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    }
                }
                .padding(16)
                .foregroundColor(.white)
                
                Spacer()
                
                // Camera View
                if showCameraPrePrompt {
                    VStack(spacing: 12) {
                        Text("Vi trenger kamera for å skanne strekkoder.")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Du kan gi tilgang når du er klar.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                        Button(action: { showCameraPrePrompt = false }) {
                            Text("Fortsett")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    BarcodeScannerView(
                        onBarcodeDetected: handleBarcodeDetected,
                        onError: handleError,
                        torchOn: $isTorchOn
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Spacer()
            }
            .background(Color.black)
            
            // Loading Indicator
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Søker produkt...")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
            
            if showScanHelp, let scanHelpTitle {
                VStack(spacing: 8) {
                    Text(scanHelpTitle)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    ForEach(scanHelpHints, id: \.self) { hint in
                        Text(hint)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.black.opacity(0.6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 90)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            
            if !showCameraPrePrompt {
                // Centered Viewfinder Overlay
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 240, height: 240)
                    .overlay(
                        Text("Skann strekkoden her")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            
        }
        .onDisappear {
            isTorchOn = false
        }
        .onAppear {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            showCameraPrePrompt = (status == .notDetermined)
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
                        dismiss()
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
                    try await productViewModel.saveManualProduct(product)
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
        .alert("Produktet finnes ikkje", isPresented: $showProductNotFound) {
            Button("Legg til selv", action: {
                showManualProduct = true
            })
            Button("Avbryt", role: .cancel) {
                scannedBarcode = nil
            }
        } message: {
            Text("Vil du legge produktet til manuelt?")
        }
    }
    
    private func handleBarcodeDetected(_ barcode: String) {
        guard scannedBarcode != barcode else { return }
        
        scannedBarcode = barcode
        isLoading = true
        
        if let cached = productViewModel.cachedProduct(barcode: barcode) {
            scannedProduct = cached
            isLoading = false
            showProductDetail = true
            Task {
                await recordCachedScan(cached)
            }
            return
        }
        
        HapticFeedbackService.shared.trigger(.barcodeDetected, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.barcodeDetected, isEnabled: preferencesViewModel.soundFeedbackEnabled)
        
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
                Task {
                    if let upgraded = await productViewModel.upgradeNutritionIfPossible(for: product) {
                        await MainActor.run {
                            scannedProduct = upgraded
                        }
                        await saveScannedProduct(upgraded)
                    }
                }
            } catch let apiError as APIService.APIError {
                await MainActor.run {
                    isLoading = false
                    switch apiError {
                    case .serverError(let code) where code == 404:
                        showProductNotFound = true
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
            }
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
                                    Text(productViewModel.product(id: scan.productId)?.name ?? "Ukjent produkt")
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
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if let userId = authViewModel.currentUser?.id {
                    recentScans = await productViewModel.recentScans(userId: userId, limit: 6)
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
    HomeView()
        .environmentObject(AppState())
        .environmentObject(LogViewModel(repository: DatabaseService()))
        .environmentObject(ProductViewModel(repository: DatabaseService()))
        .environmentObject(HealthProfileViewModel(repository: DatabaseService()))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
        .environmentObject(UserDataExportService(logRepository: DatabaseService()))
}

extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - BarcodeScannerView Wrapper

struct BarcodeScannerView: UIViewControllerRepresentable {
    let onBarcodeDetected: (String) -> Void
    let onError: (String) -> Void
    @Binding var torchOn: Bool
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onError = onError
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.setTorch(on: torchOn)
    }
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedCode: String?
    private var lastScanTime: Date = Date()
    private var videoDevice: AVCaptureDevice?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
                captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    private func setupCamera() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            onError?("Kamera er ikkje tilgjengeleg")
            return
        }
        videoDevice = videoCaptureDevice
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            onError?("Kan ikkje aksesuere kamera")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            onError?("Kan ikkje legge til video input")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [
                .ean8,
                .ean13,
                .upce,
                .code128,
                .code39,
                .code93
            ]
        } else {
            onError?("Kan ikkje legge til metadata output")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.frame = view.layer.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    func setTorch(on: Bool) {
        guard let device = videoDevice, device.hasTorch else { return }
        DispatchQueue.main.async {
            do {
                try device.lockForConfiguration()
                if on {
                    try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
            } catch {
                self.onError?("Kunne ikkje slå på lommelykt")
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
                        onBarcodeDetected?(stringValue)
                    }
                }
            }
        }
    }
}
