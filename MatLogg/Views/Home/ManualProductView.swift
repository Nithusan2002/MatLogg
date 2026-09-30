import PhotosUI
import SwiftUI
import VisionKit

struct ManualProductView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CreateProductViewModel
    @State private var showDocumentCamera = false
    @State private var labelPickerItem: PhotosPickerItem?
    @State private var frontPickerItem: PhotosPickerItem?

    let barcode: String?
    let onSaved: (Product) -> Void

    init(
        ownerUserId: UUID,
        barcode: String?,
        repository: any ProductCreationRepository,
        aiService: any NutritionLabelAIService = UnavailableNutritionLabelAIService(),
        onSaved: @escaping (Product) -> Void
    ) {
        self.barcode = barcode
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: CreateProductViewModel(
            ownerUserId: ownerUserId,
            barcode: barcode,
            repository: repository,
            imageStore: LocalProductImageStore(),
            ocrService: VisionNutritionLabelOCRService(),
            aiService: aiService
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    introduction
                    identityFields
                    nutritionCapture
                    nutritionFields
                    frontImageSection
                    sharingSection

                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.captionEmphasis).foregroundColor(AppColors.action)
                            .accessibilityLabel("Feil: \(errorMessage)")
                    }

                    PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Lagre og fortsett", systemImage: "arrow.right") {
                        Task {
                            if let product = await viewModel.complete() {
                                onSaved(product)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving || !viewModel.canComplete)
                    .opacity(viewModel.canComplete && !viewModel.isSaving ? 1 : 0.55)

                    Button("Lagre som ufullstendig utkast") {
                        Task { if await viewModel.saveIncompleteDraft() { dismiss() } }
                    }
                    .font(AppTypography.bodyEmphasis).foregroundColor(AppColors.action)
                    .frame(maxWidth: .infinity, minHeight: 44)

                    Text("Verdiene lagres slik du oppgir dem og merkes som brukeroppgitte. Kontroller alltid forslag mot emballasjen.")
                        .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                .padding(16)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Opprett egen matvare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }.foregroundColor(AppColors.action)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .fullScreenCover(isPresented: $showDocumentCamera) {
                NutritionDocumentCamera { image in
                    showDocumentCamera = false
                    Task { await viewModel.importLabelImage(image) }
                } onCancel: { showDocumentCamera = false }
                .ignoresSafeArea()
            }
            .onChange(of: labelPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await viewModel.importLabelImage(image)
                    }
                    labelPickerItem = nil
                }
            }
            .onChange(of: frontPickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await viewModel.importFrontPhoto(image)
                    }
                    frontPickerItem = nil
                }
            }
        }
    }

    private var introduction: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Label(barcode == nil ? "Din egen matvare" : "Produktet ble ikke funnet", systemImage: "plus.circle")
                    .font(AppTypography.title).foregroundColor(AppColors.deepInk)
                Text("Ta bilde av næringstabellen eller skriv inn verdiene selv.")
                    .font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                if let barcode, !barcode.isEmpty {
                    Text("Strekkode: \(barcode)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(AppColors.textSecondary).accessibilityLabel("Strekkode \(barcode)")
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var identityFields: some View {
        CardContainer {
            VStack(spacing: 14) {
                field("Produktnavn", text: $viewModel.draft.name, prompt: "For eksempel Grovbrød")
                Text("\(viewModel.draft.name.count) av \(CreateProductViewModel.maximumNameLength) tegn")
                    .font(AppTypography.caption)
                    .foregroundColor(viewModel.draft.name.count > CreateProductViewModel.maximumNameLength ? AppColors.brand : AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                field("Merke", text: $viewModel.draft.brand, prompt: "Valgfritt privat")
                field("Strekkode", text: $viewModel.draft.barcode, prompt: "Valgfritt", keyboard: .numberPad)
                Picker("Næringsverdier oppgitt per", selection: $viewModel.draft.nutritionBasis) {
                    Text("100 g").tag(NutritionBasis.per100g)
                    Text("100 ml").tag(NutritionBasis.per100ml)
                }.pickerStyle(.segmented)
            }
        }
    }

    private var nutritionCapture: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Text("Les næringstabell").font(AppTypography.sectionTitle).foregroundColor(AppColors.deepInk)
                if viewModel.isReadingLabel {
                    HStack { ProgressView(); Text("Leser etiketten …") }
                        .font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                }
                Button { showDocumentCamera = true } label: {
                    Label("Ta bilde med dokumentkamera", systemImage: "doc.viewfinder").frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered).disabled(!VNDocumentCameraViewController.isSupported)
                PhotosPicker(selection: $labelPickerItem, matching: .images) {
                    Label("Velg etikettbilde", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered)
                if viewModel.draft.labelImagePath != nil {
                    Label("Etikettbilde lagret privat", systemImage: "checkmark.circle.fill")
                        .font(AppTypography.captionEmphasis).foregroundColor(AppColors.success)
                    if FeatureFlags.nutritionLabelAIEnabled {
                        Button("Fyll inn forslag med AI") { Task { await viewModel.requestAISuggestion() } }
                            .font(AppTypography.bodyEmphasis).foregroundColor(AppColors.action).frame(minHeight: 44)
                    } else if !viewModel.localOCRText.isEmpty {
                        Text("Teksten er lest lokalt. AI-forslag er ikke aktivert i denne versjonen.")
                            .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private var nutritionFields: some View {
        let unit = viewModel.draft.nutritionBasis == .per100g ? "per 100 g" : "per 100 ml"
        return CardContainer {
            VStack(spacing: 14) {
                field("Energi", text: $viewModel.draft.calories, prompt: "kcal \(unit)", keyboard: .decimalPad)
                field("Protein", text: $viewModel.draft.protein, prompt: "g \(unit)", keyboard: .decimalPad)
                field("Karbohydrat", text: $viewModel.draft.carbohydrates, prompt: "g \(unit)", keyboard: .decimalPad)
                field("Fett", text: $viewModel.draft.fat, prompt: "g \(unit)", keyboard: .decimalPad)
                DisclosureGroup("Flere næringsverdier") {
                    VStack(spacing: 14) {
                        field("Energi", text: $viewModel.draft.energyKJ, prompt: "kJ \(unit)", keyboard: .decimalPad)
                        field("Mettet fett", text: $viewModel.draft.saturatedFat, prompt: "g \(unit)", keyboard: .decimalPad)
                        field("Sukkerarter", text: $viewModel.draft.sugars, prompt: "g \(unit)", keyboard: .decimalPad)
                        field("Fiber", text: $viewModel.draft.fiber, prompt: "g \(unit)", keyboard: .decimalPad)
                        field("Salt", text: $viewModel.draft.salt, prompt: "g \(unit)", keyboard: .decimalPad)
                        field("Natrium", text: $viewModel.draft.sodium, prompt: "g \(unit)", keyboard: .decimalPad)
                    }.padding(.top, 12)
                }
                if viewModel.extraction != nil && !viewModel.draft.aiFieldsConfirmed {
                    Button("Jeg har kontrollert AI-forslaget mot etiketten") { viewModel.confirmAISuggestion() }
                        .font(AppTypography.bodyEmphasis).foregroundColor(AppColors.action).frame(minHeight: 44)
                }
            }
        }
    }

    private var frontImageSection: some View {
        let hasFrontImage = viewModel.draft.frontImagePath != nil
        return CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                Text("Forsidebilde").font(AppTypography.sectionTitle).foregroundColor(AppColors.deepInk)
                Text("Valgfritt for private varer. Kreves hvis du vil bidra til felleskatalogen.")
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                PhotosPicker(selection: $frontPickerItem, matching: .images) {
                    Label(hasFrontImage ? "Bytt bilde" : "Velg bilde", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder private var sharingSection: some View {
        if FeatureFlags.catalogContributionsEnabled {
            CardContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hvem kan bruke varen?").font(AppTypography.sectionTitle).foregroundColor(AppColors.deepInk)
                    Picker("Deling", selection: $viewModel.draft.sharingChoice) {
                        ForEach(ProductSharingChoice.allCases, id: \.rawValue) { choice in Text(choice.label).tag(choice) }
                    }.pickerStyle(.segmented)
                    if viewModel.draft.sharingChoice == .sharedCatalog {
                        Toggle("Jeg kan dele produktbildet og vil bidra til felleskatalogen", isOn: $viewModel.shareConsent)
                            .font(AppTypography.body)
                        Text("Bidraget blir merket «Felleskatalog · Ikke verifisert» og kan bli sendt til kontroll.")
                            .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.deepInk)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .autocorrectionDisabled(keyboard != .default)
                .padding(.horizontal, 14).frame(minHeight: 50)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(title).accessibilityHint(prompt)
        }
    }
}

private struct NutritionDocumentCamera: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController(); controller.delegate = context.coordinator; return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onImage: (UIImage) -> Void
        let onCancel: () -> Void
        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) { self.onImage = onImage; self.onCancel = onCancel }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount > 0 else { onCancel(); return }; onImage(scan.imageOfPage(at: 0))
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onCancel() }
    }
}
