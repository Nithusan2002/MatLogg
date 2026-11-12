import SwiftUI
import PhotosUI

struct ManualProductView: View {
    @StateObject private var viewModel: ManualProductViewModel
    let barcode: String?
    let onSaved: (Product) -> Void

    init(barcode: String?, saveProduct: @escaping (Product) async throws -> Void,
         onSaved: @escaping (Product) -> Void) {
        self.barcode = barcode
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: ManualProductViewModel(barcode: barcode, saveProduct: saveProduct))
    }

    var body: some View {
        ManualProductForm(viewModel: viewModel, barcode: barcode, onSaved: onSaved)
    }
}

struct ManualProductForm: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ManualProductViewModel
    @EnvironmentObject private var products: ProductViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoOptions = false
    @State private var showPhotoLibrary = false
    let barcode: String?
    let onSaved: (Product) -> Void
    var keepsFlowOpen = false
    var onClose: (() async -> Bool)? = nil
    var onUseExisting: ((Product) async -> Bool)? = nil

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Steg \(viewModel.stepNumber) av 3 · \(viewModel.step.title)")
                            .font(AppTypography.captionEmphasis)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityIdentifier("manual-product-step")
                        ProgressView(value: Double(viewModel.stepNumber), total: 3)
                            .accessibilityHidden(true)
                        Group {
                            switch viewModel.step {
                            case .identity:
                                productFields
                                CardContainer {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Valgfritt").font(AppTypography.captionEmphasis)
                                            .foregroundStyle(AppColors.textSecondary)
                                        photoControls
                                        Divider()
                                        barcodeControls
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            case .basis: basisFields
                            case .nutrition: nutritionFields
                            }
                        }
                        .disabled(viewModel.isSaving)

                        if let errorMessage = viewModel.errorMessage,
                           viewModel.invalidIdentityField == nil || viewModel.step != .identity {
                            ErrorMessageView(errorMessage)
                                .font(AppTypography.captionEmphasis)
                                .accessibilityLabel("Feil: \(errorMessage)")
                        }
                        VStack(spacing: 4) {
                            if viewModel.step == .nutrition {
                                PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Lagre og loggfør", systemImage: "arrow.right") {
                                    save(only: false)
                                }
                                .disabled(viewModel.isSaving || viewModel.isLoadingImage || viewModel.isLookingUpBarcode)
                                Button("Lagre matvare") { save(only: true) }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .disabled(viewModel.isSaving || viewModel.isLoadingImage || viewModel.isLookingUpBarcode)
                                    .accessibilityIdentifier("manual-product-save-only")
                            } else {
                                PrimaryButton(title: "Neste", systemImage: "arrow.right") {
                                    viewModel.next()
                                    if let field = viewModel.invalidIdentityField {
                                        proxy.scrollTo(field.rawValue, anchor: .center)
                                        focusedField = field == .name ? "Produktnavn" : "Merke / produsent"
                                    }
                                }
                                .disabled(viewModel.isSaving || viewModel.isLoadingImage || viewModel.isLookingUpBarcode)
                                .accessibilityIdentifier("manual-product-next")
                            }
                            if viewModel.step != .identity {
                                Button("Tilbake") { viewModel.back() }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .disabled(viewModel.isSaving)
                                    .accessibilityIdentifier("manual-product-back")
                            }
                        }
                        if keepsFlowOpen && viewModel.step == .identity {
                            Text("Utkastet lagres automatisk på denne iPhonen.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(16)
                    .id("manual-product-top")
                }
                .accessibilityIdentifier("manual-product-scroll")
                .onChange(of: viewModel.step) { _, _ in
                    focusedField = nil
                    proxy.scrollTo("manual-product-top", anchor: .top)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Opprett matvare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(keepsFlowOpen ? "Lukk" : "Avbryt") {
                        Task {
                            viewModel.cancelBarcodeLookup()
                            if let onClose { if await onClose() { dismiss() } }
                            else { dismiss() }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .fullScreenCover(isPresented: $viewModel.showBarcodeScanner) {
                NavigationStack {
                    ZStack(alignment: .bottom) {
                        BarcodeScannerView(
                            onBarcodeDetected: { code in
                                Task { await viewModel.scan(code, using: products.barcodeRepository, owner: auth.currentUser?.id) }
                            },
                            onError: viewModel.scannerFailed,
                            onCameraUnavailable: { viewModel.scannerFailed("Kamera er ikke tilgjengelig. Du kan fortsette uten strekkode.") },
                            onTorchAvailabilityChanged: { _ in }, torchOn: .constant(false))
                        Text("Hold strekkoden på emballasjen foran kameraet.")
                            .font(AppTypography.bodyEmphasis)
                            .padding().background(AppColors.background)
                    }
                    .navigationTitle("Skann strekkode")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Avbryt") { viewModel.showBarcodeScanner = false }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                ProductCameraPicker { image in
                    if let image { Task { await viewModel.selectImage(image) } }
                    viewModel.showCamera = false
                }
                .ignoresSafeArea()
                .background(AppColors.imageViewerBackground.ignoresSafeArea())
            }
            .onChange(of: selectedPhoto) { _, item in
                if let item { Task { await viewModel.loadPhoto(item) } }
            }
            .confirmationDialog("Bytte næringsgrunnlag?", isPresented: $viewModel.showBasisConfirmation, titleVisibility: .visible) {
                Button("Bytt og tøm næringsverdiene", role: .destructive) { viewModel.confirmBasisChange() }
                Button("Avbryt", role: .cancel) {}
            } message: {
                Text("Fyll inn verdiene på nytt fra emballasjen for det nye grunnlaget.")
            }
            .interactiveDismissDisabled(keepsFlowOpen)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var productFields: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Om matvaren")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.deepInk)
                    .accessibilityAddTraits(.isHeader)
                if let barcode = viewModel.barcode, !barcode.isEmpty {
                    Text("Strekkode: \(barcode)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityLabel("Strekkode \(barcode)")
                }
                VStack(alignment: .leading, spacing: 6) {
                    field("Produktnavn", text: $viewModel.name, prompt: "For eksempel Grovbrød", keyboard: .default)
                    if viewModel.invalidIdentityField == .name, let error = viewModel.errorMessage {
                        ErrorMessageView(error).font(AppTypography.caption)
                    }
                }
                .id(ManualProductViewModel.IdentityField.name.rawValue)
                VStack(alignment: .leading, spacing: 6) {
                    field("Merke / produsent", text: $viewModel.brand, prompt: "For eksempel bakeriets navn", keyboard: .default, required: false)
                    if viewModel.invalidIdentityField == .brand, let error = viewModel.errorMessage {
                        ErrorMessageView(error).font(AppTypography.caption)
                    }
                }
                .id(ManualProductViewModel.IdentityField.brand.rawValue)
                FoodGroupPicker(selection: $viewModel.selectedFoodGroup)
                if viewModel.name.count >= ManualProductViewModel.maximumNameLength - 10 {
                    Text("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn")
                        .font(AppTypography.caption)
                        .foregroundColor(viewModel.name.count > ManualProductViewModel.maximumNameLength ? AppColors.errorText : AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn brukt")
                }
            }
        }
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let image = viewModel.productImage {
                ProductHeroImageView(image: image, height: 160)
            }
            Button {
                showPhotoOptions = true
            } label: {
                Label(viewModel.productImage == nil ? "Legg til bilde" : "Bytt bilde", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .accessibilityIdentifier("manual-product-photo-options")
            .accessibilityHint("Valgfritt. Bildet lagres bare på denne iPhonen.")
            if viewModel.productImage != nil {
                Button("Fjern bilde") {
                    selectedPhoto = nil
                    Task { await viewModel.selectImage(nil) }
                }
                .frame(minHeight: 44)
            }
            if viewModel.isLoadingImage { ProgressView("Åpner bilde …") }
            if let error = viewModel.imageError {
                ErrorMessageView(error).font(AppTypography.caption)
            }
        }
        .foregroundStyle(AppColors.actionText)
        .confirmationDialog("Velg produktbilde", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Ta bilde") { Task { await viewModel.openCamera() } }
            Button("Velg fra bilder") {
                selectedPhoto = nil
                showPhotoLibrary = true
            }
            Button("Avbryt", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoLibrary, selection: $selectedPhoto, matching: .images)
    }

    private func save(only: Bool) {
        Task {
            if let product = await viewModel.save(only: only) {
                if !only { onSaved(product) }
                if only || !keepsFlowOpen { dismiss() }
            }
        }
    }

    private var barcodeControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { viewModel.beginBarcodeScan() } label: {
                Label("Skann strekkode", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .disabled(viewModel.isLookingUpBarcode)
            .accessibilityIdentifier("manual-product-scan")
            .accessibilityHint("Valgfritt. Skann strekkoden fra emballasjen.")
            if viewModel.barcode != nil {
                Button("Fjern strekkode", action: viewModel.removeBarcode).frame(minHeight: 44)
            }
            if viewModel.isLookingUpBarcode {
                ProgressView("Slår opp strekkoden …")
                Button("Fortsett uten oppslaget", action: viewModel.cancelBarcodeLookup).frame(minHeight: 44)
            }
            if let product = viewModel.barcodeProduct {
                Text("Vi fant varen").font(AppTypography.sectionTitle)
                Text(product.name).font(AppTypography.bodyEmphasis)
                if let brand = product.brand { Text(brand).font(AppTypography.body) }
                Text("Kilde: \(product.nutritionSource == .matvaretabellen ? "Matvaretabellen" : product.nutritionSource == .openFoodFacts ? "Open Food Facts" : "Brukeroppgitt") · per 100 \(product.amountUnit.rawValue)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Text("Bruk treffet for å slippe å fylle inn næringsverdiene på nytt.")
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                Button("Bruk denne varen") {
                    Task {
                        if let onUseExisting { _ = await onUseExisting(product) }
                        else { onSaved(product); dismiss() }
                    }
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("manual-product-use-existing")
                Button("Fortsett med egen vare", action: viewModel.cancelBarcodeLookup).frame(minHeight: 44)
            }
            if let failure = viewModel.barcodeFailure {
                Text(failure.title).font(AppTypography.bodyEmphasis)
                Text(failure.message).font(AppTypography.caption)
                if failure == .notFound || failure == .incomplete || failure == .unclearPreparation {
                    Button("Legg strekkoden til varen", action: viewModel.acceptUnknownBarcode).frame(minHeight: 44)
                }
                Button("Prøv å skanne igjen", action: viewModel.beginBarcodeScan).frame(minHeight: 44)
                Button("Fortsett uten oppslaget", action: viewModel.cancelBarcodeLookup).frame(minHeight: 44)
            }
            if let message = viewModel.barcodeMessage {
                ErrorMessageView(message)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var basisFields: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Hva gjelder verdiene for?")
                    .font(AppTypography.sectionTitle).accessibilityAddTraits(.isHeader)
                Text("Velg samme næringsgrunnlag som på emballasjen.")
                    .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
                layout {
                    ForEach(ManualNutritionBasis.allCases, id: \.self) { basis in
                        Button { viewModel.requestBasis(basis) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.basis == basis ? "checkmark.circle.fill" : "circle")
                                    .accessibilityHidden(true)
                                Text(basis == .serving ? "Porsjon" : basis.title)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(AppTypography.bodyEmphasis)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, 8)
                            .matLoggFieldSurface(fill: viewModel.basis == basis ? AppColors.chipFillSelected : AppColors.surface)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(viewModel.basis == basis ? AppColors.actionText : AppColors.deepInk)
                        .accessibilityAddTraits(viewModel.basis == basis ? .isSelected : [])
                        .accessibilityIdentifier("manual-basis-\(basis.rawValue)")
                    }
                }
                if viewModel.basis != .serving {
                    Toggle("Legg til en porsjon (valgfritt)", isOn: $viewModel.hasCustomServing)
                }
                if viewModel.hasServing {
                    Text(viewModel.basis == .serving
                         ? "Oppgi størrelsen som næringsverdiene gjelder for."
                         : "Porsjonen er en snarvei til logging. Næringsverdiene skal fortsatt oppgis per \(viewModel.basis.title).")
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                    field("Porsjonsnavn", text: $viewModel.servingName, prompt: "For eksempel Skive", keyboard: .default)
                    field("Porsjonsstørrelse", text: $viewModel.servingAmount, prompt: "For eksempel 40", keyboard: .decimalPad, nutritionValue: false)
                    if viewModel.basis == .serving {
                        Picker("Enhet for porsjonsstørrelse", selection: Binding(get: { viewModel.servingUnit }, set: { viewModel.requestServingUnit($0) })) {
                            Text("g").tag(AmountUnit.grams)
                            Text("ml").tag(AmountUnit.milliliters)
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text("Porsjonsstørrelse i \(viewModel.portionUnit.rawValue)")
                            .font(AppTypography.caption)
                    }
                }
            }
        }
    }

    private var nutritionFields: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Næringsinnhold \(viewModel.nutritionContext)")
                    .font(AppTypography.sectionTitle).accessibilityAddTraits(.isHeader)
                Text("Fyll inn alle fire verdiene fra emballasjen.")
                    .font(AppTypography.body).foregroundStyle(AppColors.textSecondary)
                field("Energi (kcal)", text: $viewModel.calories, prompt: "For eksempel 250", keyboard: .decimalPad)
                field("Fett (g)", text: $viewModel.fat, prompt: "For eksempel 6", keyboard: .decimalPad)
                field("Karbohydrat (g)", text: $viewModel.carbs, prompt: "For eksempel 40", keyboard: .decimalPad)
                field("Protein (g)", text: $viewModel.protein, prompt: "For eksempel 8,5", keyboard: .decimalPad)
            }
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType,
        nutritionValue: Bool = true,
        required: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(required ? title : "\(title) (valgfritt)")
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.deepInk)
            TextField(prompt, text: text)
                .focused($focusedField, equals: title)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .autocorrectionDisabled(keyboard != .default)
                .matLoggInputStyle()
                .accessibilityLabel("\(title), \(required ? "obligatorisk" : "valgfritt")")
                .accessibilityIdentifier(title.components(separatedBy: " (").first ?? title)
                .accessibilityHint(keyboard == .default || !nutritionValue ? prompt : "Verdi \(viewModel.nutritionContext). \(prompt)")
        }
    }
}

private struct ProductCameraPicker: UIViewControllerRepresentable {
    let onComplete: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onComplete: onComplete) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onComplete: (UIImage?) -> Void
        init(onComplete: @escaping (UIImage?) -> Void) { self.onComplete = onComplete }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onComplete(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onComplete(info[.originalImage] as? UIImage)
        }
    }
}
