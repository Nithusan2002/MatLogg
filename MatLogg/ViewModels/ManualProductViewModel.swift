import Foundation
import Combine
import UIKit
import PhotosUI
import SwiftUI

@MainActor
final class ManualProductViewModel: ObservableObject {
    static let maximumNameLength = 80
    @Published var basis: ManualNutritionBasis = .per100g
    @Published var servingName = ""
    @Published var servingAmount = ""
    @Published var servingUnit: AmountUnit = .grams
    @Published var showBasisConfirmation = false
    private var pendingBasis: ManualNutritionBasis?
    private var pendingServingUnit: AmountUnit?

    var nutritionContext: String {
        guard basis == .serving else { return "per \(basis.title)" }
        let label = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, let amount = parseNumber(servingAmount), amount > 0 else {
            return "per porsjon/stykk"
        }
        return "per \(label) (\(amount.formatted(.number.locale(Locale(identifier: "nb_NO")))) \(servingUnit.rawValue))"
    }

    func requestBasis(_ value: ManualNutritionBasis) {
        guard value != basis else { return }
        if [calories, protein, carbs, fat].contains(where: { !$0.isEmpty }) {
            pendingServingUnit = nil
            pendingBasis = value
            showBasisConfirmation = true
        } else { basis = value }
    }

    func requestServingUnit(_ value: AmountUnit) {
        guard value != servingUnit else { return }
        if [calories, protein, carbs, fat].contains(where: { !$0.isEmpty }) {
            pendingBasis = nil
            pendingServingUnit = value
            showBasisConfirmation = true
        } else { servingUnit = value }
    }

    func confirmBasisChange() {
        guard pendingBasis != nil || pendingServingUnit != nil else { return }
        calories = ""; protein = ""; carbs = ""; fat = ""
        if let pendingBasis { basis = pendingBasis }
        if let pendingServingUnit { servingUnit = pendingServingUnit }
        self.pendingBasis = nil
        self.pendingServingUnit = nil
        errorMessage = nil
    }

    @Published var name = ""
    @Published var calories = ""
    @Published var protein = ""
    @Published var carbs = ""
    @Published var fat = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    @Published private(set) var productImage: UIImage?
    @Published private(set) var isLoadingImage = false
    @Published var showCamera = false
    @Published var imageError: String?
    private var imageRequestID = UUID()
    private var imageData: Data?
    private let cameraAuthorization: any CameraAuthorizationProviding

    func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            imageError = "Kamera er ikke tilgjengelig. Velg et bilde fra bildebiblioteket."
            return
        }
        guard await cameraAuthorization.requestAccess() else {
            imageError = "Gi MatLogg kameratilgang i Innstillinger, eller velg et bilde fra bildebiblioteket."
            return
        }
        showCamera = true
    }

    func selectImage(_ image: UIImage?) async {
        let requestID = UUID()
        imageRequestID = requestID
        imageError = nil
        guard let image else {
            productImage = nil; imageData = nil; isLoadingImage = false
            return
        }
        isLoadingImage = true
        defer { if imageRequestID == requestID { isLoadingImage = false } }
        do {
            let data = try await ProductImagePreparation.cameraJPEG(from: image)
            let preview = try await ProductImagePreparation.image(from: data, maximumPixelSize: 512)
            guard imageRequestID == requestID, !Task.isCancelled else { return }
            imageData = data
            productImage = preview
            isLoadingImage = false
        } catch {
            guard imageRequestID == requestID else { return }
            isLoadingImage = false
            imageError = "Kunne ikke åpne bildet. Prøv et annet bilde."
        }
    }

    func loadPhoto(_ item: PhotosPickerItem) async {
        let requestID = UUID()
        imageRequestID = requestID
        isLoadingImage = true
        imageError = nil
        defer { if imageRequestID == requestID { isLoadingImage = false } }
        do {
            guard let original = try await item.loadTransferable(type: Data.self) else { throw CocoaError(.fileReadCorruptFile) }
            let data = try await BackgroundWork.run { try LocalMealPhotoRepository.prepare(original, maximumPixelSize: 512) }
            let preview = try await ProductImagePreparation.image(from: data, maximumPixelSize: 512)
            guard imageRequestID == requestID, !Task.isCancelled else { return }
            imageData = data
            productImage = preview
            isLoadingImage = false
        } catch {
            guard imageRequestID == requestID else { return }
            isLoadingImage = false
            imageError = "Kunne ikke åpne bildet. Prøv et annet bilde."
        }
    }

    private let barcode: String?
    private let saveProduct: (Product) async throws -> Void

    init(barcode: String?, cameraAuthorization: any CameraAuthorizationProviding = CameraAuthorizationService(), saveProduct: @escaping (Product) async throws -> Void) {
        self.cameraAuthorization = cameraAuthorization
        self.barcode = barcode
        self.saveProduct = saveProduct
    }

    func save() async -> Product? {
        guard !isLoadingImage else { return nil }
        errorMessage = nil

        guard let values = validatedValues() else { return nil }

        let input = values.input
        let factor = 100 / input.amount
        let servings: [ServingOption]? = basis == .serving ? [
            ServingOption(label: input.label ?? "Porsjon", grams: input.amount, unit: input.unit,
                          source: .user, isDefaultSuggestion: true)
        ] : nil
        let product = Product(
            name: values.name,
            barcodeEan: barcode,
            source: "user",
            kind: .packaged,
            caloriesPer100g: Float(input.calories * factor),
            proteinGPer100g: Float(input.protein * factor),
            carbsGPer100g: Float(input.carbs * factor),
            fatGPer100g: Float(input.fat * factor),
            localImageData: imageData,
            servings: servings,
            nutritionSource: .user,
            imageSource: productImage == nil ? .none : .user,
            verificationStatus: .unverified,
            isVerified: false,
            manualNutritionInput: input,
            nutritionBasis: input.unit == .grams ? .per100g : .per100ml
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

        let unit: AmountUnit = basis == .serving ? servingUnit : (basis == .per100ml ? .milliliters : .grams)
        let amount: Double
        let label = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        if basis == .serving {
            guard !label.isEmpty, label.count <= 80,
                  let parsed = parseNumber(servingAmount), (0.1...10000).contains(parsed) else {
                errorMessage = "Oppgi et porsjonsnavn og en størrelse mellom 0,1 og 10 000 g/ml."
                return nil
            }
            amount = parsed
        } else { amount = 100 }

        guard let caloriesValue = parseNumber(calories), caloriesValue >= 0,
              caloriesValue * 100 / amount <= 10000 else {
            errorMessage = "Oppgi gyldig energi i kcal \(nutritionContext)."
            return nil
        }
        guard let proteinValue = parseNumber(protein), proteinValue >= 0,
              let carbsValue = parseNumber(carbs), carbsValue >= 0,
              let fatValue = parseNumber(fat), fatValue >= 0,
              [proteinValue, carbsValue, fatValue].allSatisfy({ $0 * 100 / amount <= 10000 }) else {
            errorMessage = "Oppgi gyldige verdier for protein, karbohydrat og fett \(nutritionContext)."
            return nil
        }
        // Mass bounds apply only to grams; volume says nothing about product density.
        if unit == .grams, proteinValue + carbsValue + fatValue > amount {
            errorMessage = "Protein, karbohydrat og fett kan til sammen ikke overstige \(amount.formatted(.number.locale(Locale(identifier: "nb_NO")))) g \(nutritionContext)."
            return nil
        }
        if unit == .grams, caloriesValue * 100 / amount > 900 {
            errorMessage = "Energi kan ikke overstige 900 kcal per 100 g."
            return nil
        }
        return ValidatedValues(name: trimmedName, input: ManualNutritionInput(
            basis: basis, amount: amount, unit: unit, label: basis == .serving ? label : nil,
            calories: caloriesValue, protein: proteinValue, carbs: carbsValue, fat: fatValue))
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
    let input: ManualNutritionInput
}
