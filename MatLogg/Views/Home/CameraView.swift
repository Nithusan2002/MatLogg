import SwiftUI
import AVFoundation
import UIKit

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
    @State private var showBarcodeEntry = false
    @State private var barcodeEntryNextAction: BarcodeEntryNextAction?
    private enum BarcodeEntryNextAction { case search, createProduct }
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
            if !showManualProduct && !showProductDetail && !showBarcodeEntry { productViewModel.resetScan() }
        }
        .onChange(of: productViewModel.scannedProduct?.id) { _, id in
            if id != nil, !showManualProduct, !showBarcodeEntry {
                showScanHelp = false
                showProductDetail = true
            }
        }
        .onChange(of: productViewModel.scanFailure) { _, failure in
            showProductNotFound = failure != nil && !showBarcodeEntry
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
        .sheet(isPresented: $showBarcodeEntry, onDismiss: {
            if let action = barcodeEntryNextAction {
                barcodeEntryNextAction = nil
                switch action {
                case .search: openSearch()
                case .createProduct: showManualProduct = true
                }
            } else if scannedProduct != nil {
                showProductDetail = true
            } else {
                productViewModel.resetScan()
            }
        }) {
            ManualBarcodeEntryView(
                productViewModel: productViewModel,
                ownerID: authViewModel.currentUser?.id,
                onSearch: {
                    barcodeEntryNextAction = .search
                    showBarcodeEntry = false
                },
                onCreateProduct: {
                    barcodeEntryNextAction = .createProduct
                    showBarcodeEntry = false
                }
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
            if productSelectionContent == nil {
                RecoverableManualLoggingView(barcode: scannedBarcode, onLogComplete: onLogComplete)
            } else {
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
                torchOn: $isTorchOn,
                detectionPaused: showBarcodeEntry || isLoading || showProductDetail || showManualProduct || showProductNotFound
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
                ScannerActionButton(title: "Skriv inn strekkode", systemImage: "number") {
                    openBarcodeEntry()
                }
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
            message: "Spor Mat bruker kameraet bare til å lese strekkoder på matvarer. Ingen bilder lagres.",
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
            message: "Gi Spor Mat kameratilgang i Innstillinger for å skanne strekkoder.",
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
            message: "Spor Mat får ikke startet kameraet på denne enheten akkurat nå. Du kan fortsatt registrere produktet manuelt eller velge en annen metode.",
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
        ScrollView {
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

                Button("Skriv inn strekkode", action: openBarcodeEntry)
                    .font(AppTypography.bodyEmphasis)
                    .frame(maxWidth: .infinity, minHeight: 44)

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
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
        }
        .safeAreaPadding(.top, 64)
    }

    private func openBarcodeEntry() {
        productViewModel.resetScan()
        isTorchOn = false
        showBarcodeEntry = true
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
        guard !isLoading, !showBarcodeEntry, !showManualProduct, !showProductDetail, !showProductNotFound else { return }

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
    var detectionPaused = false

    func makeUIViewController(context: Context) -> BarcodeScannerViewController {
        let controller = BarcodeScannerViewController()
        controller.onBarcodeDetected = onBarcodeDetected
        controller.onError = onError
        controller.onCameraUnavailable = onCameraUnavailable
        controller.onTorchAvailabilityChanged = onTorchAvailabilityChanged
        return controller
    }

    func updateUIViewController(_ uiViewController: BarcodeScannerViewController, context: Context) {
        uiViewController.detectionPaused = detectionPaused
        uiViewController.setTorch(on: torchOn)
    }

    static func dismantleUIViewController(_ uiViewController: BarcodeScannerViewController, coordinator: ()) {
        uiViewController.stopScanning()
    }
}

class BarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var detectionPaused = false
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
        guard !detectionPaused else { return }
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
