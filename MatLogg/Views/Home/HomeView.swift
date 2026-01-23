import SwiftUI
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @State private var showScanCamera = false
    @State private var showManualAdd = false
    @State private var showRawMaterials = false
    @State private var toastPayload: ReceiptPayload?
    @State private var showToast = false
    @State private var toastId = UUID()
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // MARK: - Home Tab
            HomeTabView(
                showScanCamera: $showScanCamera,
                showManualAdd: $showManualAdd,
                showRawMaterials: $showRawMaterials,
                onLogComplete: { payload in
                    Task { await appState.loadTodaysSummary() }
                    showLogToast(payload)
                }
            )
                .tabItem {
                    Label("Hjem", systemImage: "house.fill")
                }
                .tag(0)
            
            // MARK: - Logg Tab
            LoggView()
                .tabItem {
                    Label("Logg", systemImage: "list.bullet")
                }
                .tag(1)
            
            // MARK: - Favoritter Tab
            FavoritesTabView()
                .tabItem {
                    Label("Favoritter", systemImage: "star.fill")
                }
                .tag(2)
            
            // MARK: - Profile Tab
            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        .environmentObject(appState)
        .sheet(isPresented: $showScanCamera) {
            CameraView(onLogComplete: { payload in
                Task {
                    await appState.loadTodaysSummary()
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
                            await appState.undoLatestLog(
                                productId: toastPayload.product.id,
                                mealType: toastPayload.mealType,
                                amountG: Float(toastPayload.amountG)
                            )
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
                await appState.loadTodaysSummary()
            }
        }
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
}

struct HomeTabView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showScanCamera: Bool
    @Binding var showManualAdd: Bool
    @Binding var showRawMaterials: Bool
    let onLogComplete: (ReceiptPayload) -> Void
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var recentScans: [ScanHistory] = []
    @State private var showProductDetail = false
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                    HStack {
                        Text("I dag")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    
                    // Status Card
                    if appState.showGoalStatusOnHome, let summary = selectedSummary, let goal = appState.currentGoal {
                        StatusCardView(
                            summary: summary,
                            goal: goal,
                            dayLabel: "Spist i dag",
                            hideGoals: appState.safeModeHideGoals,
                            hideCalories: appState.safeModeHideCalories
                        )
                        .padding(16)
                    }
                    
                    // Dagens måltider (kompakt)
                    if let summary = selectedSummary, !summary.logs.isEmpty {
                        CompactLogListView(summary: summary, maxPerMeal: 4) { mealType in
                            appState.logSelectedDate = selectedDate
                            appState.logSelectedMeal = mealType
                            appState.selectedTab = 1
                        }
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.textSecondary)
                            Text("Ingenting logget ennå")
                                .font(AppTypography.title)
                                .foregroundColor(AppColors.ink)
                            Text("Begynn med å scanne eller legge til produkt")
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
            .navigationTitle("Hjem")
        }
        .task {
            await refreshSummaries()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
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
        .onChange(of: appState.todaysSummary?.logs.count ?? 0) { _, _ in
            Task { await loadSelectedSummary() }
        }
        
    }
    
    private func refreshSummaries() async {
        selectedDate = Date()
        await loadSelectedSummary()
        recentScans = await appState.loadRecentScans(limit: 6)
    }
    
    private func loadSelectedSummary() async {
        selectedSummary = await appState.fetchSummary(for: selectedDate)
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
