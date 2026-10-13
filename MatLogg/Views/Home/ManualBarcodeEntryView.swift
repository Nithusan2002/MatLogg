import SwiftUI

struct ManualBarcodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var productViewModel: ProductViewModel
    @StateObject private var entry = ManualBarcodeEntryViewModel()
    @FocusState private var inputFocused: Bool
    let ownerID: UUID?
    let onSearch: () -> Void
    let onCreateProduct: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Strekkodenummer", text: $entry.input)
                        .keyboardType(.numberPad)
                        .textContentType(nil)
                        .focused($inputFocused)
                        .disabled(productViewModel.isScanning)
                        .accessibilityIdentifier("manualBarcodeInput")
                    if let message = entry.validationMessage {
                        Text(message).foregroundStyle(AppColors.textSecondary)
                    }
                } footer: {
                    Text("Skriv inn tallene under strekkoden. Hvis varen ikke er lagret på enheten, sendes nummeret til Open Food Facts når du trykker Finn produkt.")
                }
                Section {
                    PrimaryButton(title: productViewModel.isScanning ? "Henter produkt …" : "Finn produkt") {
                        inputFocused = false
                        Task { await entry.submit(using: productViewModel, ownerID: ownerID) }
                    }
                    .disabled(productViewModel.isScanning)
                    .accessibilityIdentifier("findManualBarcode")
                    if productViewModel.isScanning { ProgressView("Henter produkt …") }
                }
                if let failure = productViewModel.scanFailure {
                    Section {
                        Text(failure.title).font(AppTypography.bodyEmphasis)
                        Text(failure.message)
                        Button("Søk etter vare", action: onSearch)
                        Button("Registrer manuelt", action: onCreateProduct)
                    }
                }
            }
            .accessibilityIdentifier("manual-barcode-form")
            .navigationTitle("Skriv inn strekkode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { inputFocused = false }
                        .foregroundColor(AppColors.actionText)
                        .accessibilityIdentifier("manual-barcode-keyboard-done")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") {
                        productViewModel.resetScan()
                        dismiss()
                    }
                }
            }
            .onAppear { inputFocused = true }
            .onChange(of: entry.input) { _, _ in
                if productViewModel.scannedBarcode != nil { productViewModel.resetScan() }
            }
            .onChange(of: productViewModel.scannedProduct?.id) { _, id in
                if id != nil { dismiss() }
            }
        }
        .interactiveDismissDisabled(productViewModel.isScanning)
    }
}
