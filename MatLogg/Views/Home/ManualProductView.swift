import SwiftUI

struct ManualProductView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ManualProductViewModel

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
                    introduction
                    productFields

                    if let errorMessage = viewModel.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                            .font(AppTypography.captionEmphasis)
                            .foregroundColor(AppColors.action)
                            .accessibilityLabel("Feil: \(errorMessage)")
                    }

                    PrimaryButton(
                        title: viewModel.isSaving ? "Lagrer …" : "Lagre og fortsett",
                        systemImage: "arrow.right"
                    ) {
                        Task {
                            if let product = await viewModel.save() {
                                onSaved(product)
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                    .opacity(viewModel.isSaving ? 0.6 : 1)

                    Text("Verdiene lagres slik du oppgir dem og merkes som brukerregistrerte. Du kan kontrollere dem mot emballasjen.")
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
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var introduction: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Label("Produktet ble ikke funnet", systemImage: "barcode.viewfinder")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.deepInk)
                Text("Legg inn næringsverdiene per 100 g fra emballasjen.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                if let barcode, !barcode.isEmpty {
                    Text("Strekkode: \(barcode)")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .accessibilityLabel("Strekkode \(barcode)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var productFields: some View {
        CardContainer {
            VStack(spacing: 16) {
                field("Produktnavn", text: $viewModel.name, prompt: "For eksempel Grovbrød", keyboard: .default)
                Text("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn")
                    .font(AppTypography.caption)
                    .foregroundColor(viewModel.name.count > ManualProductViewModel.maximumNameLength ? AppColors.brand : AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityLabel("\(viewModel.name.count) av \(ManualProductViewModel.maximumNameLength) tegn brukt")
                field("Energi", text: $viewModel.calories, prompt: "kcal per 100 g", keyboard: .numberPad)
                field("Protein", text: $viewModel.protein, prompt: "g per 100 g", keyboard: .decimalPad)
                field("Karbohydrat", text: $viewModel.carbs, prompt: "g per 100 g", keyboard: .decimalPad)
                field("Fett", text: $viewModel.fat, prompt: "g per 100 g", keyboard: .decimalPad)
            }
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        prompt: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.deepInk)
            TextField(prompt, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .default ? .sentences : .never)
                .autocorrectionDisabled(keyboard != .default)
                .padding(.horizontal, 14)
                .frame(minHeight: 50)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel(title)
                .accessibilityHint(prompt)
        }
    }
}
