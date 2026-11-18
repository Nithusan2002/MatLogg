import Foundation

/// Optional catalog metadata. Invalid enrichment must not reject an otherwise usable food.
nonisolated enum ProductPackageLabel {
    static func validated(_ raw: String?) -> String? {
        guard let raw, raw.count <= 100 else { return nil }
        let text = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !text.isEmpty, text.contains(where: \.isNumber), text.contains(where: \.isLetter), !text.hasPrefix("-"),
              !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return text
    }

    /// Enrich a result value only; never persist or replace a user's nutrition/identity.
    static func fillingMissingValue(in stored: Product, from incoming: Product) -> Product {
        let barcode = stored.barcodeEan.flatMap { $0.isEmpty ? nil : $0 }
        let incomingBarcode = incoming.barcodeEan.flatMap { $0.isEmpty ? nil : $0 }
        if let barcode, let incomingBarcode, barcode != incomingBarcode { return stored }
        guard stored.id == incoming.id || (barcode != nil && barcode == incomingBarcode),
              stored.source == "openfoodfacts", incoming.source == "openfoodfacts",
              stored.nutritionSource == .openFoodFacts, incoming.nutritionSource == .openFoodFacts,
              stored.manualNutritionInput == nil, stored.packageQuantityLabel == nil,
              let label = validated(incoming.packageQuantityLabel) else { return stored }
        var result = stored
        result.packageQuantityLabel = label
        return result
    }

}
