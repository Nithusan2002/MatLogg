import Foundation
import Combine

@MainActor
final class ManualBarcodeEntryViewModel: ObservableObject {
    @Published var input = "" {
        didSet { validationMessage = nil }
    }
    @Published private(set) var validationMessage: String?

    func submit(using products: ProductViewModel, ownerID: UUID?) async {
        guard !products.isScanning, let barcode = validatedBarcode() else { return }
        products.resetScan()
        await products.scan(barcode: barcode, ownerUserId: ownerID)
    }

    func validatedBarcode() -> String? {
        do {
            return try ProductBarcodeParser.lookupBarcode(fromManualInput: input)
        } catch {
            validationMessage = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Skriv inn strekkodenummeret."
                : "Kontroller nummeret. Strekkoden må ha 8, 12, 13 eller 14 sifre og et gyldig kontrollsiffer."
            return nil
        }
    }
}
