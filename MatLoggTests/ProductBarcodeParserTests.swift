import Testing
@testable import MatLogg

struct ProductBarcodeParserTests {
    @Test func ordinaryEANPassesThroughUnchanged() throws {
        let code = ScannedBarcode(rawValue: "7035620067709", symbology: .ean13)

        #expect(try ProductBarcodeParser.lookupBarcode(from: code) == "7035620067709")
    }

    @Test func gs1DataMatrixExtractsAndNormalizesGTIN13() throws {
        let code = ScannedBarcode(
            rawValue: "]d20107035620067709132609211726102310639100911343",
            symbology: .gs1DataMatrix
        )

        #expect(try ProductBarcodeParser.lookupBarcode(from: code) == "7035620067709")
    }

    @Test func gs1DataMatrixSupportsParenthesizedApplicationIdentifiers() throws {
        let code = ScannedBarcode(
            rawValue: "(01)07035620067709(13)260921(17)261023(10)639100911343",
            symbology: .gs1DataMatrix
        )

        #expect(try ProductBarcodeParser.lookupBarcode(from: code) == "7035620067709")
    }

    @Test func gs1DataMatrixFindsProductElementAfterGroupSeparator() throws {
        let code = ScannedBarcode(
            rawValue: "]d210LOT123\u{001D}0107035620067709\u{001D}17261023",
            symbology: .gs1DataMatrix
        )

        #expect(try ProductBarcodeParser.lookupBarcode(from: code) == "7035620067709")
    }

    @Test func gs1DataMatrixRejectsMissingProductIdentifier() {
        let code = ScannedBarcode(rawValue: "]d210LOT123\u{001D}17261023", symbology: .gs1DataMatrix)

        #expect(throws: ProductBarcodeParserError.dataMatrixMissingGTIN) {
            try ProductBarcodeParser.lookupBarcode(from: code)
        }
    }

    @Test func gs1DataMatrixRejectsInvalidCheckDigit() {
        let code = ScannedBarcode(rawValue: "]d20107035620067708", symbology: .gs1DataMatrix)

        #expect(throws: ProductBarcodeParserError.invalidGTIN) {
            try ProductBarcodeParser.lookupBarcode(from: code)
        }
    }
}
