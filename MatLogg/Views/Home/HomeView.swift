import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // MARK: - Home Tab
            HomeTabView()
                .tabItem {
                    Label("Hjem", systemImage: "house.fill")
                }
                .tag(0)
            
            // MARK: - Historikk Tab
            LoggerTabView()
                .tabItem {
                    Label("Historikk", systemImage: "list.bullet")
                }
                .tag(1)
            
            // MARK: - Favoritter Tab
            FavoritesTabView()
                .tabItem {
                    Label("Favoritter", systemImage: "star.fill")
                }
                .tag(2)
            
            // MARK: - Progress Tab
            ProgressTabView()
                .tabItem {
                    Label("Fremgang", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)
            
            // MARK: - Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(4)
        }
        .environmentObject(appState)
        .onAppear {
            Task {
                await appState.loadTodaysSummary()
            }
        }
    }
}

struct HomeTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var showScanCamera = false
    @State private var showHistoryPanel = false
    @State private var showManualAdd = false
    @State private var showRawMaterials = false
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var yesterdaySummary: DailySummary?
    @State private var recentScans: [ScanHistory] = []
    @State private var showReceipt = false
    @State private var receiptPayload: ReceiptPayload?
    @State private var pendingScanAfterReceipt = false
    @State private var showProductDetail = false
    @State private var selectedProduct: Product?
    @State private var showDatePicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                    HStack {
                        Button(action: { shiftSelectedDate(by: -1) }) {
                            Image(systemName: "chevron.left")
                        }
                        .frame(width: 44, height: 44)
                        
                        Spacer()
                        
                        Button(action: { showDatePicker = true }) {
                            HStack(spacing: 6) {
                                Text(dayTitle)
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                                Image(systemName: "calendar")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { shiftSelectedDate(by: 1) }) {
                            Image(systemName: "chevron.right")
                        }
                        .frame(width: 44, height: 44)
                        .opacity(canGoToNextDay ? 1 : 0.3)
                        .disabled(!canGoToNextDay)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    if isTodaySelected, let yesterdaySummary, !yesterdaySummary.logs.isEmpty {
                        Button(action: copyYesterdayLogs) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                Text("Legg til det samme som i går")
                            }
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.surface)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    
                    // Status Card
                    if appState.showGoalStatusOnHome, let summary = selectedSummary, let goal = appState.currentGoal {
                        StatusCardView(
                            summary: summary,
                            goal: goal,
                            dayLabel: isTodaySelected ? "Spist i dag" : "Spist \(dayTitle.lowercased())",
                            hideGoals: appState.safeModeHideGoals,
                            hideCalories: appState.safeModeHideCalories
                        )
                        .padding(16)
                    }
                    
                    // Logging List
                    if let summary = selectedSummary, !summary.logs.isEmpty {
                        LogListView(summary: summary)
                            .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.textSecondary)
                            Text(isTodaySelected ? "Ingenting logget ennå" : "Ingen logging denne dagen")
                                .font(AppTypography.title)
                                .foregroundColor(AppColors.ink)
                            Text(isTodaySelected ? "Begynn med å scanne eller legge til produkt" : "Velg en annen dag for å logge mat")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .padding(.horizontal, 20)
                    }
                    }
                    .padding(.bottom, 140)
                }
            }
            .navigationTitle("MatLogg")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showHistoryPanel = true }) {
                        Image(systemName: "clock.fill")
                    }
                }
            }
            .sheet(isPresented: $showHistoryPanel) {
                ScanHistoryView()
            }
        }
        .task {
            await refreshSummaries()
        }
        .onChange(of: selectedDate) {
            Task {
                await loadSelectedSummary()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                if !recentScans.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentScans.prefix(6)) { scan in
                                if let product = appState.getProduct(scan.productId) {
                                    Button(action: {
                                        selectedProduct = product
                                        showProductDetail = true
                                    }) {
                                        Text(product.name)
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.ink)
                                            .lineLimit(1)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(AppColors.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(AppColors.separator, lineWidth: 1)
                                            )
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                
                ScanButtonLarge(action: { showScanCamera = true })
                
                HStack(spacing: 12) {
                    Button(action: { showRawMaterials = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "leaf")
                            Text("Søk / Råvarer")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.ink)
                    }
                    
                    Spacer()
                    
                    Button(action: { showManualAdd = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Legg til manuelt")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.brand)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(16)
            .background(AppColors.background)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $showScanCamera) {
            CameraView(onLogComplete: { payload in
                Task {
                    await refreshSummaries()
                }
                receiptPayload = payload
                showScanCamera = false
                showReceipt = true
            })
        }
        .fullScreenCover(isPresented: $showReceipt, onDismiss: {
            if pendingScanAfterReceipt {
                showScanCamera = true
                pendingScanAfterReceipt = false
            }
        }) {
            if let payload = receiptPayload {
                ReceiptView(
                    product: payload.product,
                    amountG: payload.amountG,
                    nutrition: payload.nutrition,
                    mealType: payload.mealType,
                    onAction: handleReceiptAction
                )
            }
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
        .sheet(isPresented: $showProductDetail) {
            if let product = selectedProduct {
                ProductDetailView(
                    product: product,
                    appState: appState,
                    onLogComplete: { payload in
                        receiptPayload = payload
                        showReceipt = true
                    }
                )
            }
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("Velg dato")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    
                    DatePicker(
                        "Velg dato",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                }
                .padding(16)
                .background(AppColors.background.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Ferdig") { showDatePicker = false }
                            .foregroundColor(AppColors.brand)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }
    
    private func refreshSummaries() async {
        await loadSelectedSummary()
        yesterdaySummary = await appState.fetchSummary(for: yesterdayDate())
        recentScans = await appState.loadRecentScans(limit: 6)
    }
    
    private func loadSelectedSummary() async {
        selectedSummary = await appState.fetchSummary(for: selectedDate)
    }
    
    private func copyYesterdayLogs() {
        Task {
            await appState.copyLogs(from: yesterdayDate(), to: Date())
            await refreshSummaries()
        }
    }
    
    private func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    }
    
    private func handleReceiptAction(_ action: ReceiptAction) {
        switch action {
        case .scanNext:
            pendingScanAfterReceipt = true
        case .addAgain, .close:
            break
        }
    }

    private var isTodaySelected: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private var canGoToNextDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }
    
    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "I dag"
        }
        if Calendar.current.isDateInYesterday(selectedDate) {
            return "I går"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: selectedDate)
    }
    
    private func shiftSelectedDate(by days: Int) {
        if days > 0, Calendar.current.isDateInToday(selectedDate) {
            return
        }
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
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
                            Text(overCalories > 0 ? "Over mål" : "Igjen")
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
                
                    Divider()
                        .overlay(AppColors.separator)
                    
                    VStack(spacing: 12) {
                        ProgressRow(
                            label: "Proteiner",
                            valueText: "\(Int(summary.totalProtein))g / \(Int(goal.proteinTargetG))g",
                            progress: progressValue(current: Double(summary.totalProtein), target: Double(goal.proteinTargetG))
                        )
                        ProgressRow(
                            label: "Karbohydrater",
                            valueText: "\(Int(summary.totalCarbs))g / \(Int(goal.carbsTargetG))g",
                            progress: progressValue(current: Double(summary.totalCarbs), target: Double(goal.carbsTargetG))
                        )
                        ProgressRow(
                            label: "Fett",
                            valueText: "\(Int(summary.totalFat))g / \(Int(goal.fatTargetG))g",
                            progress: progressValue(current: Double(summary.totalFat), target: Double(goal.fatTargetG))
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

struct LogListView: View {
    @EnvironmentObject var appState: AppState
    let summary: DailySummary
    
    private let mealTitles: [String: String] = [
        "frokost": "Frokost",
        "lunsj": "Lunsj",
        "middag": "Middag",
        "snacks": "Snacks"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(summary.logsByMeal.sorted(by: { $0.key < $1.key }), id: \.key) { mealType, logs in
                VStack(alignment: .leading, spacing: 8) {
                    Text(mealTitles[mealType, default: mealType.capitalized])
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    
                    ForEach(logs) { log in
                        LogItemView(log: log)
                    }
                }
            }
        }
    }
}

struct LogItemView: View {
    @EnvironmentObject var appState: AppState
    let log: FoodLog
    @State private var showDeleteConfirm = false
    
    private var productName: String {
        appState.getProduct(log.productId)?.name ?? "Ukjent produkt"
    }
    
    var body: some View {
        CardContainer {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productName)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    
                    Text("\(Int(log.amountG))g")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if !appState.safeModeHideCalories {
                    Text("\(log.calories) kcal")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Slett", systemImage: "trash")
            }
        }
        .alert("Slett logging?", isPresented: $showDeleteConfirm) {
            Button("Slett", role: .destructive) {
                Task {
                    await appState.deleteLog(log)
                }
            }
        }
    }
}

struct ScanButtonLarge: View {
    let action: () -> Void
    
    var body: some View {
        PrimaryButton(title: "Skann", systemImage: "barcode.viewfinder", height: 72, action: action)
    }
}

struct ScanHistoryView: View {
    @EnvironmentObject var appState: AppState
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
                            if let product = appState.getProduct(scan.productId) {
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
            recentScans = await appState.loadRecentScans()
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
        appState.getProduct(scan.productId)?.name ?? "Ukjent produkt"
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    let onLogComplete: (ReceiptPayload) -> Void
    
    private let apiService = APIService()
    
    @State private var scannedBarcode: String?
    @State private var scannedProduct: Product?
    @State private var isLoading = false
    @State private var isTorchOn = false
    @State private var scanHelpTitle: String?
    @State private var scanHelpHints: [String] = []
    @State private var showScanHelp = false
    @State private var showProductDetail = false
    @State private var showProductNotFound = false
    
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
                BarcodeScannerView(
                    onBarcodeDetected: handleBarcodeDetected,
                    onError: handleError,
                    torchOn: $isTorchOn
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
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
        .onDisappear {
            isTorchOn = false
        }
        .sheet(isPresented: $showProductDetail) {
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
        
        if let cached = appState.getProductByBarcode(barcode) {
            scannedProduct = cached
            isLoading = false
            showProductDetail = true
            Task {
                await appState.saveScannedProduct(cached)
            }
            return
        }
        
        HapticFeedbackService.shared.trigger(.barcodeDetected, isEnabled: appState.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.barcodeDetected, isEnabled: appState.soundFeedbackEnabled)
        
        Task {
            do {
                let product = try await apiService.searchProductByBarcodeOpenFoodFacts(barcode)
                await MainActor.run {
                    scannedProduct = product
                    isLoading = false
                    showScanHelp = false
                    showProductDetail = true
                }
                await appState.saveScannedProduct(product)
                Task {
                    if let upgraded = await appState.upgradeNutritionIfPossible(for: product) {
                        await MainActor.run {
                            scannedProduct = upgraded
                        }
                        await appState.saveScannedProduct(upgraded)
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
                            isEnabled: appState.hapticsFeedbackEnabled
                        )
                        SoundFeedbackService.shared.play(
                            .error,
                            isEnabled: appState.soundFeedbackEnabled
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
                        isEnabled: appState.hapticsFeedbackEnabled
                    )
                    SoundFeedbackService.shared.play(
                        .error,
                        isEnabled: appState.soundFeedbackEnabled
                    )
                    presentScanHelp(
                        title: "Noe gikk galt ved skanning",
                        hints: ["Hold kamera rolig", "Mer lys", "Flytt nærmere strekkoden"]
                    )
                }
            }
        }
    }
    
    private func handleError(_ error: String) {
        presentScanHelp(
            title: error,
            hints: ["Hold kamera rolig", "Mer lys", "Flytt nærmere strekkoden"]
        )
        HapticFeedbackService.shared.trigger(.error, isEnabled: appState.hapticsFeedbackEnabled)
        SoundFeedbackService.shared.play(.error, isEnabled: appState.soundFeedbackEnabled)
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

struct LoggerTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Historikk kommer snart")
                    .foregroundColor(AppColors.textSecondary)
            }
            .navigationTitle("Historikk")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AppState())
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
            captureSession.startRunning()
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
