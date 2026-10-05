import SwiftUI
import PhotosUI

struct ManualProductView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ManualProductViewModel

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showPhotoOptions = false
    @State private var showPhotoLibrary = false

    let barcode: String?
    let onSaved: (Product) -> Void

    init(
        barcode: String?,
        saveProduct: @escaping (Product) async throws -> Void,
        onSaved: @escaping (Product) -> Void
    ) {
        self.barcode = barcode
        self.onSaved = onSaved
        _viewModel = StateObject(
            wrappedValue: ManualProductViewModel(barcode: barcode, saveProduct: saveProduct)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    productFields
                    photoControls.disabled(viewModel.isSaving || viewModel.isLoadingImage)
                    nutritionFields

                    if let errorMessage = viewModel.errorMessage {
                        ErrorMessageView(errorMessage)
                            .font(AppTypography.captionEmphasis)
                            .accessibilityLabel("Feil: \(errorMessage)")
                    }

                    PrimaryButton(
                        title: viewModel.isSaving ? "Lagrer …" : "Lagre og velg mengde",
                        systemImage: "arrow.right"
                    ) {
                        Task {
                            if let product = await viewModel.save() {
                                onSaved(product)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || viewModel.isLoadingImage)
                    .opacity(viewModel.isSaving ? 0.6 : 1)

                    Text("Merket som brukerregistrert.")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Opprett produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
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
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var productFields: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Om produktet")
                    .font(AppTypography.sectionTitle)
                    .foregroundColor(AppColors.deepInk)
                    .accessibilityAddTraits(.isHeader)
                if let barcode, !barcode.isEmpty {
                    Text("Strekkode: \(barcode)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityLabel("Strekkode \(barcode)")
                }
                field("Produktnavn", text: $viewModel.name, prompt: "For eksempel Grovbrød", keyboard: .default)
                if viewModel.name.count >= ManualProductViewModel.maximumNameLength - 10 {
                    Text("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn")
                        .font(AppTypography.caption)
                        .foregroundColor(viewModel.name.count > ManualProductViewModel.maximumNameLength ? AppColors.errorText : AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn brukt")
                }
                if viewModel.name.count > ManualProductViewModel.maximumNameLength {
                    ErrorMessageView("Produktnavnet er for langt")
                        .font(AppTypography.caption)
                }
            }
        }
    }

    private var photoControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    if let image = viewModel.productImage {
                        ProductHeroImageView(image: image, height: 160)
                    }
                    Button {
                        showPhotoOptions = true
                    } label: {
                        Label(viewModel.productImage == nil ? "Legg til bilde (valgfritt)" : "Bytt bilde", systemImage: "photo")
                            .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("manual-product-photo-options")
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
            }
            Text("Bildet lagres bare på denne iPhonen.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
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

    private var nutritionFields: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Næringsinnhold")
                        .font(AppTypography.sectionTitle)
                        .foregroundColor(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Velg samme næringsgrunnlag som på emballasjen og fyll inn verdiene derfra.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                Picker("Næringsinnhold per", selection: Binding(
                    get: { viewModel.basis }, set: { viewModel.requestBasis($0) }
                )) {
                    ForEach(ManualNutritionBasis.allCases, id: \.self) { basis in
                        Text(basis.title).tag(basis)
                    }
                }
                .pickerStyle(.menu)
                .disabled(viewModel.isSaving)
                if viewModel.basis == .serving {
                    field("Porsjonsnavn", text: $viewModel.servingName, prompt: "For eksempel Skive", keyboard: .default)
                    field("Porsjonsstørrelse", text: $viewModel.servingAmount, prompt: "For eksempel 40", keyboard: .decimalPad, nutritionValue: false)
                    Picker("Enhet for porsjonsstørrelse", selection: Binding(get: { viewModel.servingUnit }, set: { viewModel.requestServingUnit($0) })) {
                        Text("g").tag(AmountUnit.grams)
                        Text("ml").tag(AmountUnit.milliliters)
                    }
                    .pickerStyle(.segmented)
                }
                field("Energi (kcal)", text: $viewModel.calories, prompt: "For eksempel 250", keyboard: .numberPad)
                field("Protein (g)", text: $viewModel.protein, prompt: "For eksempel 8,5", keyboard: .decimalPad)
                field("Karbohydrat (g)", text: $viewModel.carbs, prompt: "For eksempel 40", keyboard: .decimalPad)
                field("Fett (g)", text: $viewModel.fat, prompt: "For eksempel 6", keyboard: .decimalPad)
            }
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType,
        nutritionValue: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.deepInk)
            Text("Obligatorisk")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .autocorrectionDisabled(keyboard != .default)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("\(title), obligatorisk")
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
