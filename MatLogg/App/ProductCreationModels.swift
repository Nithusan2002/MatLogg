import Foundation

enum ProductSharingChoice: String, Codable, CaseIterable {
    case privateOnly
    case sharedCatalog

    var label: String {
        switch self {
        case .privateOnly: return "Bare for meg"
        case .sharedCatalog: return "Bidra til felleskatalog"
        }
    }
}

enum ProductDraftStatus: String, Codable {
    case incomplete
    case ready
}

struct ProductDraft: Codable, Identifiable, Equatable {
    var id: UUID
    let ownerUserId: UUID
    var name: String
    var brand: String
    var barcode: String
    var kind: ProductKind
    var nutritionBasis: NutritionBasis
    var calories: String
    var energyKJ: String
    var protein: String
    var carbohydrates: String
    var fat: String
    var saturatedFat: String
    var sugars: String
    var fiber: String
    var salt: String
    var sodium: String
    var labelImagePath: String?
    var frontImagePath: String?
    var sharingChoice: ProductSharingChoice
    var aiFieldsConfirmed: Bool
    var updatedAt: Date

    init(id: UUID = UUID(), ownerUserId: UUID, barcode: String? = nil) {
        self.id = id
        self.ownerUserId = ownerUserId
        name = ""
        brand = ""
        self.barcode = barcode ?? ""
        kind = .packaged
        nutritionBasis = .per100g
        calories = ""
        energyKJ = ""
        protein = ""
        carbohydrates = ""
        fat = ""
        saturatedFat = ""
        sugars = ""
        fiber = ""
        salt = ""
        sodium = ""
        labelImagePath = nil
        frontImagePath = nil
        sharingChoice = .privateOnly
        aiFieldsConfirmed = false
        updatedAt = Date()
    }

    var status: ProductDraftStatus { requiredValues == nil ? .incomplete : .ready }

    var requiredValues: RequiredNutritionValues? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let calories = Self.number(calories), (0...900).contains(calories),
              let protein = Self.number(protein), (0...100).contains(protein),
              let carbohydrates = Self.number(carbohydrates), (0...100).contains(carbohydrates),
              let fat = Self.number(fat), (0...100).contains(fat),
              protein + carbohydrates + fat <= 100 else { return nil }
        return RequiredNutritionValues(
            name: trimmedName,
            calories: calories,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat
        )
    }

    static func number(_ raw: String) -> Double? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}

struct RequiredNutritionValues: Equatable {
    let name: String
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
}

nonisolated struct ExtractedNutritionField: Codable, Equatable, Sendable {
    let value: Double?
    let unit: String?
    let confidence: Double
    let evidence: String?
}

nonisolated struct NutritionExtraction: Codable, Equatable, Sendable {
    let basis: NutritionBasis?
    let energyKJ: ExtractedNutritionField
    let energyKcal: ExtractedNutritionField
    let fat: ExtractedNutritionField
    let saturatedFat: ExtractedNutritionField
    let carbohydrates: ExtractedNutritionField
    let sugars: ExtractedNutritionField
    let fiber: ExtractedNutritionField
    let protein: ExtractedNutritionField
    let salt: ExtractedNutritionField
    let sodium: ExtractedNutritionField
}

enum CatalogSubmissionStatus: String, Codable {
    case privateDraft = "private_draft"
    case pendingProcessing = "pending_processing"
    case needsReview = "needs_review"
    case publicUnverified = "public_unverified"
    case verified
    case rejected
    case merged
    case expired
}

struct CatalogSubmission: Codable, Identifiable {
    let id: UUID
    let ownerUserId: UUID
    let productId: UUID
    let productSnapshot: Product
    let labelImagePath: String
    let frontImagePath: String
    let aiFieldsConfirmed: Bool
    var status: CatalogSubmissionStatus
    let explicitConsent: Bool
    let createdAt: Date
    var updatedAt: Date
}

struct CatalogProduct: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let brand: String?
    let barcode: String?
    let nutritionBasis: NutritionBasis
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let frontImageURL: URL?
    let status: CatalogSubmissionStatus
    let updatedAt: Date
}
