import Foundation
import Combine
import UIKit
import PhotosUI
import SwiftUI

@MainActor
final class ManualProductViewModel: ObservableObject {
    enum IdentityField: String { case name, brand }
    @Published private(set) var invalidIdentityField: IdentityField?
    static let maximumNameLength = 80
    @Published var step: ManualProductStep = .identity { didSet { inputChanged?() } }
    @Published var brand = "" { didSet { clearIdentityError(for: .brand); inputChanged?() } }
    @Published var hasCustomServing = false { didSet { inputChanged?() } }
    @Published private(set) var barcode: String? { didSet { inputChanged?() } }
    @Published var showBarcodeScanner = false
    @Published private(set) var barcodeProduct: Product?
    @Published private(set) var barcodeFailure: BarcodeLookupFailure?
    @Published private(set) var barcodeMessage: String?
    @Published private(set) var isLookingUpBarcode = false
    private var barcodeRequest = UUID()
    private var pendingBarcode: String?

    var hasServing: Bool { basis == .serving || hasCustomServing }
    var portionUnit: AmountUnit { basis == .serving ? servingUnit : (basis == .per100ml ? .milliliters : .grams) }
    var stepNumber: Int { (ManualProductStep.allCases.firstIndex(of: step) ?? 0) + 1 }

    func next() {
        errorMessage = nil
        switch step {
        case .identity: if validateIdentity() { step = .basis }
        case .basis: if validateServing() { step = .nutrition }
        case .nutrition: break
        }
    }

    func back() {
        errorMessage = nil
        switch step {
        case .identity: break
        case .basis: step = .identity
        case .nutrition: step = .basis
        }
    }

    func beginBarcodeScan() { cancelBarcodeLookup(); showBarcodeScanner = true }

    func cancelBarcodeLookup() {
        barcodeRequest = UUID(); isLookingUpBarcode = false
        barcodeProduct = nil; barcodeFailure = nil; barcodeMessage = nil; pendingBarcode = nil
    }

    func scannerFailed(_ message: String) {
        cancelBarcodeLookup(); showBarcodeScanner = false; barcodeMessage = message
    }

    func removeBarcode() { barcode = nil; cancelBarcodeLookup() }

    func acceptUnknownBarcode() {
        guard let pendingBarcode, barcodeFailure == .notFound || barcodeFailure == .incomplete || barcodeFailure == .unclearPreparation else { return }
        barcode = pendingBarcode; cancelBarcodeLookup()
    }

    func scan(_ code: ScannedBarcode, using repository: any BarcodeLookupRepository, owner: UUID?) async {
        guard !isLookingUpBarcode else { return }
        showBarcodeScanner = false
        cancelBarcodeLookup()
        let parsed: String
        do { parsed = try ProductBarcodeParser.lookupBarcode(from: code) }
        catch { barcodeMessage = "Kunne ikke lese strekkoden. Prøv igjen eller fortsett uten."; return }
        let request = UUID(); barcodeRequest = request; pendingBarcode = parsed; isLookingUpBarcode = true
        defer { if barcodeRequest == request { isLookingUpBarcode = false } }
        do {
            let cached = await repository.cached(barcode: parsed, owner: owner)
            guard barcodeRequest == request, !Task.isCancelled else { return }
            let product: Product
            if let cached { product = cached } else { product = try await repository.fetch(barcode: parsed) }
            guard barcodeRequest == request, !Task.isCancelled else { return }
            barcodeProduct = product
        } catch {
            guard barcodeRequest == request, !Task.isCancelled else { return }
            barcodeFailure = BarcodeLookupFailure.classify(error)
        }
    }
    @Published var basis: ManualNutritionBasis = .per100g { didSet { inputChanged?() } }
    @Published var servingName = "" { didSet { inputChanged?() } }
    @Published var servingAmount = "" { didSet { inputChanged?() } }
    @Published var servingUnit: AmountUnit = .grams { didSet { inputChanged?() } }
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

    @Published var selectedFoodGroup: FoodGroup? { didSet { inputChanged?() } }
    @Published var name = "" { didSet { clearIdentityError(for: .name); inputChanged?() } }
    @Published var calories = "" { didSet { inputChanged?() } }
    @Published var protein = "" { didSet { inputChanged?() } }
    @Published var carbs = "" { didSet { inputChanged?() } }
    @Published var fat = "" { didSet { inputChanged?() } }
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    @Published private(set) var productImage: UIImage?
    @Published private(set) var isLoadingImage = false
    @Published var showCamera = false
    @Published var imageError: String?
    private var imageRequestID = UUID()
    private var imageData: Data? { didSet { inputChanged?() } }
    var inputChanged: (() -> Void)?
    var productID = UUID()
    private let cameraAuthorization: any CameraAuthorizationProviding

    func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            imageError = "Kamera er ikke tilgjengelig. Velg et bilde fra bildebiblioteket."
            return
        }
        guard await cameraAuthorization.requestAccess() else {
            imageError = "Gi Spor Mat kameratilgang i Innstillinger, eller velg et bilde fra bildebiblioteket."
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

    private let saveProduct: (Product) async throws -> Void
    private let storeProductOnly: ((Product) async throws -> Void)?

    init(barcode: String?, cameraAuthorization: any CameraAuthorizationProviding = CameraAuthorizationService(), saveProductOnly: ((Product) async throws -> Void)? = nil, saveProduct: @escaping (Product) async throws -> Void) {
        self.cameraAuthorization = cameraAuthorization
        self.barcode = barcode
        self.saveProduct = saveProduct
        self.storeProductOnly = saveProductOnly
    }

    var input: ManualProductInput {
        ManualProductInput(name: name, calories: calories, protein: protein, carbs: carbs, fat: fat,
                           basis: basis, servingName: servingName, servingAmount: servingAmount,
                           servingUnit: servingUnit, imageData: imageData, selectedFoodGroup: selectedFoodGroup?.rawValue,
                           brand: brand, hasCustomServing: hasCustomServing, wizardStep: step, barcode: barcode)
    }

    func restoreInput(_ input: ManualProductInput, productID: UUID) {
        self.productID = productID
        brand = input.brand ?? ""; hasCustomServing = input.hasCustomServing ?? false
        step = input.wizardStep ?? .identity
        barcode = input.barcode ?? barcode
        selectedFoodGroup = input.selectedFoodGroup.flatMap(FoodGroup.init(rawValue:))
        name = input.name; calories = input.calories; protein = input.protein
        carbs = input.carbs; fat = input.fat; basis = input.basis
        servingName = input.servingName; servingAmount = input.servingAmount
        servingUnit = input.servingUnit; imageData = input.imageData
        productImage = input.imageData.flatMap(UIImage.init(data:))
    }

    func save(only: Bool = false) async -> Product? {
        guard !isLoadingImage, !isSaving, !isLookingUpBarcode else { return nil }
        errorMessage = nil

        guard let values = validatedValues() else { return nil }

        let input = values.input
        let factor = 100 / input.amount
        let servings: [ServingOption]? = hasServing ? [
            ServingOption(label: servingName.trimmingCharacters(in: .whitespacesAndNewlines), grams: parseNumber(servingAmount) ?? input.amount, unit: portionUnit,
                          source: .user, isDefaultSuggestion: true)
        ] : nil
        let product = Product(
            id: productID,
            name: values.name,
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : brand.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedFoodGroup: selectedFoodGroup?.rawValue,
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
            if only, let storeProductOnly { try await storeProductOnly(product) }
            else { try await saveProduct(product) }
            return product
        } catch {
            errorMessage = "Kunne ikke lagre produktet lokalt. Prøv igjen."
            return nil
        }
    }

    private func clearIdentityError(for field: IdentityField) {
        guard invalidIdentityField == field else { return }
        invalidIdentityField = nil; errorMessage = nil
    }

    private func validateIdentity() -> Bool {
        invalidIdentityField = nil
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name.count > Self.maximumNameLength {
            invalidIdentityField = .name
            errorMessage = name.isEmpty ? "Skriv inn et produktnavn." : "Produktnavnet kan være maksimalt 80 tegn."
            return false
        }
        if brand.trimmingCharacters(in: .whitespacesAndNewlines).count > 80 {
            invalidIdentityField = .brand
            errorMessage = "Merke / produsent kan være maksimalt 80 tegn."
            return false
        }
        return true
    }

    private func validateServing() -> Bool {
        guard hasServing else { return true }
        let label = servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= 80, let amount = parseNumber(servingAmount), (0.1...10000).contains(amount) else {
            errorMessage = "Oppgi et porsjonsnavn og en størrelse mellom 0,1 og 10 000 g/ml."; return false
        }
        return true
    }

    private func validatedValues() -> ValidatedValues? {
        guard validateIdentity(), validateServing() else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
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
