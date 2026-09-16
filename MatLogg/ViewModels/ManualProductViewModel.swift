import Foundation
import Combine

@MainActor
final class ManualProductViewModel: ObservableObject {
    static let maximumNameLength = 80
    @Published var name = ""
    @Published var calories = ""
    @Published var protein = ""
    @Published var carbs = ""
    @Published var fat = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    private let barcode: String?
    private let saveProduct: (Product) async throws -> Void

    init(barcode: String?, saveProduct: @escaping (Product) async throws -> Void) {
        self.barcode = barcode
        self.saveProduct = saveProduct
    }

    func save() async -> Product? {
        errorMessage = nil

        guard let values = validatedValues() else { return nil }

        let product = Product(
            name: values.name,
            barcodeEan: barcode,
            source: "user",
            kind: .packaged,
            caloriesPer100g: values.calories,
            proteinGPer100g: values.protein,
            carbsGPer100g: values.carbs,
            fatGPer100g: values.fat,
            nutritionSource: .user,
            imageSource: .none,
            verificationStatus: .unverified,
            isVerified: false
        )

        isSaving = true
        defer { isSaving = false }

        do {
            try await saveProduct(product)
            return product
        } catch {
            errorMessage = "Kunne ikke lagre produktet lokalt. Prøv igjen."
            return nil
        }
    }

    private func validatedValues() -> ValidatedValues? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Skriv inn et produktnavn."
            return nil
        }

        guard trimmedName.count <= Self.maximumNameLength else {
            errorMessage = "Produktnavnet kan være maksimalt \(Self.maximumNameLength) tegn."
            return nil
        }

        guard let caloriesValue = parseNumber(calories),
              caloriesValue.rounded() == caloriesValue,
              (1...900).contains(caloriesValue) else {
            errorMessage = "Energi må være et helt tall mellom 1 og 900 kcal per 100 g."
            return nil
        }

        guard let proteinValue = parseMacro(protein),
              let carbsValue = parseMacro(carbs),
              let fatValue = parseMacro(fat) else {
            errorMessage = "Oppgi protein, karbohydrat og fett mellom 0 og 100 g per 100 g."
            return nil
        }

        guard proteinValue + carbsValue + fatValue <= 100 else {
            errorMessage = "Protein, karbohydrat og fett kan til sammen ikke overstige 100 g per 100 g."
            return nil
        }

        return ValidatedValues(
            name: trimmedName,
            calories: Int(caloriesValue),
            protein: Float(proteinValue),
            carbs: Float(carbsValue),
            fat: Float(fatValue)
        )
    }

    private func parseMacro(_ value: String) -> Double? {
        guard let number = parseNumber(value), (0...100).contains(number) else { return nil }
        return number
    }

    private func parseNumber(_ value: String) -> Double? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let number = Double(normalized), number.isFinite else { return nil }
        return number
    }
}

private struct ValidatedValues {
    let name: String
    let calories: Int
    let protein: Float
    let carbs: Float
    let fat: Float
}
