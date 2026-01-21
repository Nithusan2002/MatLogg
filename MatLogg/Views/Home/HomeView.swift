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
            
            // MARK: - Logger Tab
            LoggerTabView()
                .tabItem {
                    Label("Logger", systemImage: "list.bullet")
                }
                .tag(1)
            
            // MARK: - Favoritter Tab
            FavoritesTabView()
                .tabItem {
                    Label("Favoritter", systemImage: "star.fill")
                }
                .tag(2)
            
            // MARK: - Settings Tab
            SettingsTabView()
                .tabItem {
                    Label("Innstillinger", systemImage: "gear")
                }
                .tag(3)
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status Card
                if let summary = appState.todaysSummary, let goal = appState.currentGoal {
                    StatusCardView(summary: summary, goal: goal)
                        .padding(16)
                }
                
                // Meal Type Selector
                MealTypeSelector()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                // Logging List
                if let summary = appState.todaysSummary, !summary.logs.isEmpty {
                    LogListView(summary: summary)
                        .padding(.horizontal, 16)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Ingenting logget ennå")
                            .font(.headline)
                        Text("Begynn med å scanne eller legge til produkt")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
                }
                
                Spacer()
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
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                ScanButtonLarge(action: { showScanCamera = true })
                
                HStack(spacing: 12) {
                    NavigationLink(destination: ManualAddView()) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                            Text("Legg til manuelt")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $showScanCamera) {
            CameraView()
        }
    }
}

struct StatusCardView: View {
    let summary: DailySummary
    let goal: Goal
    
    var caloriePercentage: Double {
        Double(summary.totalCalories) / Double(goal.dailyCalories)
    }
    
    var calorieColor: Color {
        if caloriePercentage < 0.5 {
            return .green
        } else if caloriePercentage < 1.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    var remainingCalories: Int {
        max(0, goal.dailyCalories - summary.totalCalories)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Main Calorie Display with Pie Chart
            HStack(spacing: 20) {
                // Pie Chart
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray6), lineWidth: 12)
                    
                    // Colored progress circle
                    Circle()
                        .trim(from: 0, to: min(caloriePercentage, 1.0))
                        .stroke(calorieColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: caloriePercentage)
                    
                    // Center text
                    VStack(spacing: 2) {
                        Text("\(Int(caloriePercentage * 100))%")
                            .font(.system(size: 20, weight: .bold))
                        Text("av mål")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                
                // Stats Column
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spist")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(summary.totalCalories) kcal")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mål")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(goal.dailyCalories) kcal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Igjen")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(remainingCalories) kcal")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(calorieColor)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Macros
            HStack(spacing: 12) {
                MacroView(
                    label: "P",
                    value: Int(summary.totalProtein),
                    target: Int(goal.proteinTargetG),
                    unit: "g",
                    color: .red
                )
                MacroView(
                    label: "C",
                    value: Int(summary.totalCarbs),
                    target: Int(goal.carbsTargetG),
                    unit: "g",
                    color: .orange
                )
                MacroView(
                    label: "F",
                    value: Int(summary.totalFat),
                    target: Int(goal.fatTargetG),
                    unit: "g",
                    color: .yellow
                )
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct MacroView: View {
    let label: String
    let value: Int
    let target: Int
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(value)")
                .font(.headline)
            
            Text("\(target)\(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MealTypeSelector: View {
    @EnvironmentObject var appState: AppState
    
    let mealTypes = ["Frokost", "Lunsj", "Middag", "Snask"]
    let mealTypeKeys = ["breakfast", "lunch", "dinner", "snack"]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<mealTypes.count, id: \.self) { index in
                Button(action: {
                    appState.selectedMealType = mealTypeKeys[index]
                }) {
                    Text(mealTypes[index])
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(
                            appState.selectedMealType == mealTypeKeys[index] ? .white : .primary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            appState.selectedMealType == mealTypeKeys[index] ?
                            Color.blue : Color(.systemGray6)
                        )
                        .cornerRadius(6)
                }
            }
        }
    }
}

struct LogListView: View {
    @EnvironmentObject var appState: AppState
    let summary: DailySummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(summary.logsByMeal.sorted(by: { $0.key < $1.key }), id: \.key) { mealType, logs in
                VStack(alignment: .leading, spacing: 8) {
                    Text(mealType.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
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
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Produkt navn") // TODO: Fetch product name
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("\(Int(log.amountG))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(log.calories) kcal")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 32))
                Text("SKANN")
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .cornerRadius(12)
        }
    }
}

struct ScanHistoryView: View {
    @State private var recentScans: [ScanHistory] = []
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Nylig brukt")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                
                if recentScans.isEmpty {
                    Text("Ingen nylige skanninger")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List(recentScans) { scan in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Produkt") // TODO: Fetch name
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Skanner for \(scan.scannedAt.timeAgoDisplay())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

struct CameraView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var scannedBarcode: String?
    @State private var scannedProduct: Product?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showProductDetail = false
    @State private var showProductNotFound = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Avbryt") { dismiss() }
                    Spacer()
                    Button(action: {}) {
                        Image(systemName: "flashlight.on.fill")
                    }
                }
                .padding(16)
                .foregroundColor(.white)
                
                Spacer()
                
                // Camera View
                BarcodeScannerView(
                    onBarcodeDetected: handleBarcodeDetected,
                    onError: handleError
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Spacer()
                
                // Viewfinder Overlay
                VStack(spacing: 12) {
                    Text("Pek kamera mot strekkode")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                
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
        }
        .sheet(isPresented: $showProductDetail) {
            if let product = scannedProduct {
                ProductDetailView(product: product, appState: appState)
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
        .alert("Feil", isPresented: $showError) {
            Button("Ok", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Ein feil oppstod")
        }
    }
    
    private func handleBarcodeDetected(_ barcode: String) {
        guard scannedBarcode != barcode else { return }
        
        scannedBarcode = barcode
        isLoading = true
        
        HapticFeedbackService.shared.trigger(.barcodeDetected)
        SoundFeedbackService.shared.play(.barcodeDetected)
        
        // Simulate API lookup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // For MVP, create mock product from barcode
            let mockProduct = Product(
                id: UUID(),
                name: "Produkt \(barcode.prefix(4))",
                brand: nil,
                category: nil,
                barcodeEan: barcode,
                source: "database",
                caloriesPer100g: Int.random(in: 50...300),
                proteinGPer100g: Float.random(in: 5...25),
                carbsGPer100g: Float.random(in: 5...50),
                fatGPer100g: Float.random(in: 2...20),
                sugarGPer100g: nil,
                fiberGPer100g: nil,
                sodiumMgPer100g: nil,
                imageUrl: nil,
                isVerified: false,
                createdAt: Date()
            )
            
            scannedProduct = mockProduct
            isLoading = false
            showProductDetail = true
        }
    }
    
    private func handleError(_ error: String) {
        errorMessage = error
        showError = true
        HapticFeedbackService.shared.trigger(.error)
        SoundFeedbackService.shared.play(.error)
    }
}

struct ManualAddView: View {
    @Environment(\.dismiss) var dismiss
    @State private var productName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    
    var body: some View {
        NavigationStack {
            Form {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Legg til") { dismiss() }
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
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Favoritter")
        }
    }
}

struct LoggerTabView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Text("Logger-detaljer kommer snart")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Logger")
        }
    }
}

struct SettingsTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptics feedback", isOn: $appState.hapticsFeedbackEnabled)
                    Toggle("Lyd", isOn: $appState.soundFeedbackEnabled)
                }
                
                Section("Konto") {
                    Button("Logg ut") {
                        appState.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Innstillinger")
            .onChange(of: appState.hapticsFeedbackEnabled) { _, newValue in
                appState.updateFeedbackSettings(
                    haptics: newValue,
                    sound: appState.soundFeedbackEnabled
                )
            }
            .onChange(of: appState.soundFeedbackEnabled) { _, newValue in
                appState.updateFeedbackSettings(
                    haptics: appState.hapticsFeedbackEnabled,
                    sound: newValue
                )
            }
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
    
    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onError = onError
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {}
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    var onError: ((String) -> Void)?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastScannedCode: String?
    private var lastScanTime: Date = Date()
    
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

