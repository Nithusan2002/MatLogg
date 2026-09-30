import Combine
import Foundation
import UIKit

@MainActor
final class CreateProductViewModel: ObservableObject {
    static let maximumNameLength = 80

    @Published var draft: ProductDraft
    @Published private(set) var isSaving = false
    @Published private(set) var isReadingLabel = false
    @Published private(set) var localOCRText = ""
    @Published private(set) var extraction: NutritionExtraction?
    @Published private(set) var errorMessage: String?
    @Published var shareConsent = false

    private let repository: any ProductCreationRepository
    private let imageStore: any ProductImageStoring
    private let ocrService: any NutritionLabelOCRService
    private let aiService: any NutritionLabelAIService
    private let aiEnabled: () -> Bool
    private let contributionsEnabled: () -> Bool

    convenience init(ownerUserId: UUID, barcode: String? = nil, repository: any ProductCreationRepository) {
        self.init(
            ownerUserId: ownerUserId,
            barcode: barcode,
            repository: repository,
            imageStore: LocalProductImageStore(),
            ocrService: VisionNutritionLabelOCRService(),
            aiService: UnavailableNutritionLabelAIService(),
            aiEnabled: { FeatureFlags.nutritionLabelAIEnabled },
            contributionsEnabled: { FeatureFlags.catalogContributionsEnabled }
        )
    }

    init(
        ownerUserId: UUID,
        barcode: String? = nil,
        repository: any ProductCreationRepository,
        imageStore: any ProductImageStoring,
        ocrService: any NutritionLabelOCRService,
        aiService: any NutritionLabelAIService,
        aiEnabled: @escaping () -> Bool = { FeatureFlags.nutritionLabelAIEnabled },
        contributionsEnabled: @escaping () -> Bool = { FeatureFlags.catalogContributionsEnabled }
    ) {
        draft = ProductDraft(ownerUserId: ownerUserId, barcode: barcode)
        self.repository = repository
        self.imageStore = imageStore
        self.ocrService = ocrService
        self.aiService = aiService
        self.aiEnabled = aiEnabled
        self.contributionsEnabled = contributionsEnabled
    }

    var canComplete: Bool { draft.requiredValues != nil && draft.name.count <= Self.maximumNameLength }
    var canContribute: Bool {
        contributionsEnabled()
            && draft.kind == .packaged
            && !draft.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.labelImagePath != nil
            && draft.frontImagePath != nil
            && shareConsent
    }

    func saveIncompleteDraft() async -> Bool {
        errorMessage = nil
        draft.updatedAt = Date()
        do {
            try await repository.saveDraft(draft)
            return true
        } catch {
            errorMessage = "Utkastet kunne ikke lagres lokalt."
            return false
        }
    }

    func importLabelImage(_ image: UIImage) async {
        isReadingLabel = true
        errorMessage = nil
        defer { isReadingLabel = false }
        do {
            draft.labelImagePath = try await imageStore.store(image, kind: .nutritionLabel, draftID: draft.id)
            localOCRText = try await ocrService.recognizeText(in: image)
            draft.updatedAt = Date()
            try await repository.saveDraft(draft)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Bildet kunne ikke behandles."
        }
    }

    func importFrontPhoto(_ image: UIImage) async {
        errorMessage = nil
        do {
            draft.frontImagePath = try await imageStore.store(image, kind: .front, draftID: draft.id)
            draft.updatedAt = Date()
            try await repository.saveDraft(draft)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Forsidebildet kunne ikke behandles."
        }
    }

    func requestAISuggestion() async {
        guard aiEnabled(), let labelImagePath = draft.labelImagePath else { return }
        isReadingLabel = true
        errorMessage = nil
        defer { isReadingLabel = false }
        do {
            let imageData = try await imageStore.data(at: labelImagePath)
            let result = try await aiService.extract(
                assetID: draft.id,
                imageData: imageData,
                localOCRText: localOCRText,
                language: "nb"
            )
            extraction = result
            apply(result)
            draft.aiFieldsConfirmed = false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "AI-avlesning feilet. Fyll inn manuelt."
        }
    }

    func confirmAISuggestion() {
        guard extraction != nil else { return }
        draft.aiFieldsConfirmed = true
    }

    func complete() async -> Product? {
        errorMessage = nil
        guard draft.name.count <= Self.maximumNameLength else {
            errorMessage = "Produktnavnet kan være maksimalt \(Self.maximumNameLength) tegn."
            return nil
        }
        guard let values = draft.requiredValues else {
            errorMessage = "Fyll inn navn, energi, protein, karbohydrat og fett med gyldige verdier."
            return nil
        }
        if draft.sharingChoice == .sharedCatalog, !canContribute {
            errorMessage = "Bidrag krever merke, etikettbilde, forsidebilde og samtykke."
            return nil
        }

        let sodium = ProductDraft.number(draft.sodium)
        let product = Product(
            name: values.name,
            brand: normalizedOptional(draft.brand),
            barcodeEan: normalizedOptional(draft.barcode),
            source: "user",
            kind: draft.kind,
            caloriesPer100g: Float(values.calories),
            proteinGPer100g: Float(values.protein),
            carbsGPer100g: Float(values.carbohydrates),
            fatGPer100g: Float(values.fat),
            saturatedFatGPer100g: ProductDraft.number(draft.saturatedFat).map(Float.init),
            sugarGPer100g: ProductDraft.number(draft.sugars).map(Float.init),
            fiberGPer100g: ProductDraft.number(draft.fiber).map(Float.init),
            saltGPer100g: ProductDraft.number(draft.salt).map(Float.init),
            sodiumMgPer100g: sodium.map { Int(($0 * 1_000).rounded()) },
            imageUrl: draft.frontImagePath.map { URL(fileURLWithPath: $0).absoluteString },
            nutritionSource: .user,
            imageSource: draft.frontImagePath == nil ? .none : .user,
            verificationStatus: .unverified,
            isVerified: false,
            nutritionBasis: draft.nutritionBasis
        )
        let submission: CatalogSubmission?
        if draft.sharingChoice == .sharedCatalog {
            guard let labelImagePath = draft.labelImagePath,
                  let frontImagePath = draft.frontImagePath else {
                errorMessage = "Bidrag krever etikettbilde og forsidebilde."
                return nil
            }
            submission = CatalogSubmission(
                id: stableSubmissionID(for: draft.id),
                ownerUserId: draft.ownerUserId,
                productId: product.id,
                productSnapshot: product,
                labelImagePath: labelImagePath,
                frontImagePath: frontImagePath,
                aiFieldsConfirmed: draft.aiFieldsConfirmed,
                status: .pendingProcessing,
                explicitConsent: shareConsent,
                createdAt: Date(),
                updatedAt: Date()
            )
        } else {
            submission = nil
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.completeDraft(draft, product: product, submission: submission)
            return product
        } catch {
            errorMessage = "Produktet kunne ikke lagres lokalt. Prøv igjen."
            return nil
        }
    }

    private func apply(_ result: NutritionExtraction) {
        if let basis = result.basis { draft.nutritionBasis = basis }
        assign(result.energyKcal, to: &draft.calories)
        assign(result.energyKJ, to: &draft.energyKJ)
        assign(result.protein, to: &draft.protein)
        assign(result.carbohydrates, to: &draft.carbohydrates)
        assign(result.fat, to: &draft.fat)
        assign(result.saturatedFat, to: &draft.saturatedFat)
        assign(result.sugars, to: &draft.sugars)
        assign(result.fiber, to: &draft.fiber)
        assign(result.salt, to: &draft.salt)
        assign(result.sodium, to: &draft.sodium)
    }

    private func assign(_ field: ExtractedNutritionField, to target: inout String) {
        guard let value = field.value else { return }
        target = value.formatted(.number.precision(.fractionLength(0...3)).locale(Locale(identifier: "nb_NO")))
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func stableSubmissionID(for draftID: UUID) -> UUID {
        Product.catalogID(source: "catalog-submission", externalID: draftID.uuidString)
    }
}
