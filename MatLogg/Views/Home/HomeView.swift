import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showScanCamera = false
    @State private var showManualAdd = false
    @State private var showRawMaterials = false
    @State private var toastPayload: ReceiptPayload?
    @State private var showToast = false
    @State private var toastId = UUID()
    @State private var showAddActions = false
    @State private var previousTab: AppTab = .home
    
    var body: some View {
        TabView(selection: tabSelection) {
            HomeTabView(
                showScanCamera: $showScanCamera,
                showManualAdd: $showManualAdd,
                showRawMaterials: $showRawMaterials,
                onLogComplete: { payload in
                    Task { await loadTodaysSummary() }
                    showLogToast(payload)
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
                    Label("Fremgang", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(AppTab.progress)

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .environmentObject(appState)
        .sheet(isPresented: $showScanCamera) {
            CameraView(onLogComplete: { payload in
                Task {
                    await loadTodaysSummary()
                }
                showScanCamera = false
                showLogToast(payload)
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
            RawMaterialsSearchView()
                .environmentObject(appState)
        }
        .overlay(alignment: .bottom) {
            if showToast, let toastPayload {
                LogToastView(
                    payload: toastPayload,
                    onUndo: {
                        Task {
                            guard let userId = authViewModel.currentUser?.id else { return }
                            if await logViewModel.undoLatestLog(
                                productId: toastPayload.product.id,
                                mealType: toastPayload.mealType,
                                amountG: Float(toastPayload.amountG),
                                userId: userId
                            ) {
                                await loadTodaysSummary()
                                await appState.refreshSyncStatus()
                            } else if let message = logViewModel.errorMessage {
                                appState.errorMessage = message
                            }
                        }
                        hideToast()
                    },
                    onScanNext: {
                        hideToast()
                        showScanCamera = true
                    },
                    onDismiss: {
                        hideToast()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
        .confirmationDialog("Legg til mat", isPresented: $showAddActions) {
            Button("Skann strekkode") { showScanCamera = true }
            Button("Søk i matvarer") { showRawMaterials = true }
            Button("Legg til manuelt") { showManualAdd = true }
            Button("Avbryt", role: .cancel) {}
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
    
    private func showLogToast(_ payload: ReceiptPayload) {
        toastPayload = payload
        showToast = true
        let currentId = UUID()
        toastId = currentId
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if toastId == currentId {
                hideToast()
            }
        }
    }
    
    private func hideToast() {
        withAnimation {
            showToast = false
        }
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
    let onLogComplete: (ReceiptPayload) -> Void
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var recentScans: [ScanHistory] = []
    @State private var showProductDetail = false
    @State private var selectedProduct: Product?
    @State private var selectedMealForLog: MealPresentation?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    homeHeader

                    if preferencesViewModel.showGoalStatusOnHome, let summary = selectedSummary, let goal = healthProfileViewModel.currentGoal {
                        StatusCardView(
                            summary: summary,
                            goal: goal,
                            dayLabel: "Dagens fremgang",
                            hideGoals: preferencesViewModel.safeModeHideGoals,
                            hideCalories: preferencesViewModel.safeModeHideCalories
                        )
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
                        Text("4 måltider")
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
                                showRawMaterials = true
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
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
        .sheet(isPresented: $showProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(
                    product: product,
                    appState: appState,
                    onLogComplete: { payload in
                        onLogComplete(payload)
                    }
                )
            }
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
        guard let userId = authViewModel.currentUser?.id else {
            selectedSummary = nil
            return
        }
        selectedSummary = await logViewModel.fetchSummary(userId: userId, date: selectedDate)
    }

    private var homeHeader: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.success)
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "leaf.fill").foregroundColor(.white))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("MatLogg")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.ink)
                Text(dateLabel)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
            Button {
                appState.selectedTab = .profile
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.ink)
                    .frame(width: 44, height: 44)
                    .background(AppColors.accent.opacity(0.8), in: Circle())
            }
            .accessibilityLabel("Åpne profil")
        }
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
        .init(key: "snacks", title: "Snacks", icon: "sparkles")
    ]
}

struct QuickSearchBar: View {
    let onSearch: () -> Void
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSearch) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(AppColors.info)
                    Text("Søk etter mat eller råvarer")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppColors.surface, in: Capsule())
                .overlay(Capsule().stroke(AppColors.separator, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Åpner matvaresøk")

            Button(action: onScan) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title3.weight(.bold))
                    .foregroundColor(AppColors.ink)
                    .frame(width: 50, height: 50)
                    .background(AppColors.accent, in: Circle())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: meal.icon)
                    .foregroundColor(AppColors.ink)
                    .frame(width: 36, height: 36)
                    .background(meal.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 2) {
                    Text(meal.title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
                    Text(logs.isEmpty ? "Ikke logget ennå" : "\(logs.count) innslag")
                        .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if !logs.isEmpty && !hideCalories {
                    Text("\(totalCalories) kcal").font(AppTypography.captionEmphasis).foregroundColor(AppColors.ink)
                }
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(AppColors.textSecondary)
            }

            if logs.isEmpty {
                Button(action: onAdd) {
                    Label("Legg til i \(meal.title.lowercased())", systemImage: "plus")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(meal.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 9) {
                    ForEach(logs.prefix(3)) { log in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(productName(log.productId)).font(AppTypography.body).foregroundColor(AppColors.ink).lineLimit(1)
                                Text("\(Int(log.amountG)) g").font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            if !hideCalories {
                                Text("\(log.calories) kcal").font(AppTypography.captionEmphasis).foregroundColor(AppColors.ink)
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
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3).fill(meal.tint).frame(width: 4).padding(.vertical, 14)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture {
            if !logs.isEmpty { onOpen() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint(logs.isEmpty ? "Bruk Legg til-knappen for å logge mat" : "Åpner alle innslag med redigering")
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
        CardContainer {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(dayLabel)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Text(hideCalories ? "—" : "\(summary.totalCalories) kcal")
                            .font(AppTypography.hero)
                            .foregroundColor(AppColors.ink)
                    }
                    
                    Spacer()
                    
                    if !hideGoals {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(overCalories > 0 ? "Utover mål" : "Igjen")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            Text(hideCalories ? "—" : "\(overCalories > 0 ? overCalories : remainingCalories) kcal")
                                .font(AppTypography.hero)
                                .foregroundColor(AppColors.ink)
                        }
                    }
                }
                
                if !hideGoals {
                    Text("Mål: \(goal.dailyCalories) kcal")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)

                    HStack(spacing: 8) {
                        SummaryPill(
                            label: "Protein",
                            value: "\(Int(summary.totalProtein)) g",
                            tintColor: AppColors.macroProteinTint
                        )
                        SummaryPill(
                            label: "Karbo",
                            value: "\(Int(summary.totalCarbs)) g",
                            tintColor: AppColors.macroCarbTint
                        )
                        SummaryPill(
                            label: "Fett",
                            value: "\(Int(summary.totalFat)) g",
                            tintColor: AppColors.macroFatTint
                        )
                    }
                
                    Divider()
                        .overlay(AppColors.separator)
                    
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

struct ReceiptPayload {
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
            ProductDetailView(product: product, appState: appState, onLogComplete: nil)
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
        .alert("Produktet finnes ikkje", isPresented: $showProductNotFound) {
            Button("Legg til selv", action: {
                dismiss()
                // TODO: Navigate to create product flow
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
                await saveScannedProduct(cached)
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
                        .foregroundColor(AppColors.brand)
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
                                    .foregroundColor(AppColors.info)
                                    .frame(width: 40, height: 40)
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
