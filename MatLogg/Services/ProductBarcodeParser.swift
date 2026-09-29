import Foundation

struct ScannedBarcode: Equatable, Sendable {
    enum Symbology: Equatable, Sendable {
        case ean8
        case ean13
        case upce
        case code128
        case code39
        case code93
        case gs1DataMatrix
    }

    let rawValue: String
    let symbology: Symbology
}

enum ProductBarcodeParserError: Error, Equatable {
    case emptyCode
    case dataMatrixMissingGTIN
    case invalidGTIN
}

/// Converts transient camera payloads into the product identifier used by the
/// local cache and Open Food Facts. GS1 traceability fields are intentionally
/// discarded; MatLogg only needs the GTIN for product lookup.
struct ProductBarcodeParser {
    nonisolated static func lookupBarcode(from scannedCode: ScannedBarcode) throws -> String {
        switch scannedCode.symbology {
        case .gs1DataMatrix:
            return try lookupBarcode(fromGS1DataMatrix: scannedCode.rawValue)
        case .ean8, .ean13, .upce, .code128, .code39, .code93:
            let barcode = scannedCode.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !barcode.isEmpty else { throw ProductBarcodeParserError.emptyCode }
            return barcode
        }
    }

    private nonisolated static func lookupBarcode(fromGS1DataMatrix rawValue: String) throws -> String {
        var payload = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.hasPrefix("]d2") {
            payload.removeFirst(3)
        }

        let gtin: String?
        if let applicationIdentifier = payload.range(of: "(01)") {
            gtin = fourteenDigits(at: applicationIdentifier.upperBound, in: payload)
        } else {
            let groupSeparator = Character("\u{001D}")
            let elementStrings = payload.split(separator: groupSeparator, omittingEmptySubsequences: true)
            let productElement = elementStrings.first { $0.hasPrefix("01") }
            gtin = productElement.flatMap { element in
                let elementString = String(element)
                let gtinStart = elementString.index(elementString.startIndex, offsetBy: 2)
                return fourteenDigits(at: gtinStart, in: elementString)
            }
        }

        guard let gtin else { throw ProductBarcodeParserError.dataMatrixMissingGTIN }
        guard hasValidCheckDigit(gtin) else { throw ProductBarcodeParserError.invalidGTIN }
        return canonicalBarcode(fromGTIN14: gtin)
    }

    private nonisolated static func fourteenDigits(
        at startIndex: String.Index,
        in value: String
    ) -> String? {
        guard let endIndex = value.index(startIndex, offsetBy: 14, limitedBy: value.endIndex) else {
            return nil
        }
        let candidate = String(value[startIndex..<endIndex])
        guard candidate.utf8.count == 14,
              candidate.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return candidate
    }

    private nonisolated static func hasValidCheckDigit(_ gtin: String) -> Bool {
        let digits = gtin.compactMap(\.wholeNumberValue)
        guard digits.count == gtin.count, let checkDigit = digits.last else { return false }

        let weightedSum = digits.dropLast().enumerated().reduce(0) { partialResult, item in
            let (index, digit) = item
            let positionFromRight = digits.count - 1 - index
            let weight = positionFromRight.isMultiple(of: 2) ? 1 : 3
            return partialResult + (digit * weight)
        }
        return (10 - (weightedSum % 10)) % 10 == checkDigit
    }

    private nonisolated static func canonicalBarcode(fromGTIN14 gtin: String) -> String {
        if gtin.hasPrefix("000000") {
            return String(gtin.dropFirst(6))
        }
        if gtin.hasPrefix("00") {
            return String(gtin.dropFirst(2))
        }
        if gtin.hasPrefix("0") {
            return String(gtin.dropFirst())
        }
        return gtin
    }
}
