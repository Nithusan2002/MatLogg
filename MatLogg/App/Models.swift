import CryptoKit
import Foundation

// MARK: - User & Auth

nonisolated struct User: Codable, Identifiable, Sendable {
    let id: UUID
    let email: String
    let firstName: String
    let lastName: String
    let authProvider: String // "apple", "google", "email"
    let createdAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var isLocalProfile: Bool { authProvider == "local" }

    static func local(id: UUID, createdAt: Date = Date()) -> User {
        User(
            id: id,
            email: "",
            firstName: "",
            lastName: "",
            authProvider: "local",
            createdAt: createdAt
        )
    }
}

// MARK: - Goals

nonisolated struct Goal: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let goalType: String // "weight_loss", "maintain", "gain"
    let dailyCalories: Int
    let proteinTargetG: Float
    let carbsTargetG: Float
    let fatTargetG: Float
    let intent: GoalIntent?
    let pace: GoalPace?
    let activityLevel: ActivityLevel?
    let createdDate: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        goalType: String,
        dailyCalories: Int,
        proteinTargetG: Float,
        carbsTargetG: Float,
        fatTargetG: Float,
        intent: GoalIntent? = nil,
        pace: GoalPace? = nil,
        activityLevel: ActivityLevel? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.goalType = goalType
        self.dailyCalories = dailyCalories
        self.proteinTargetG = proteinTargetG
        self.carbsTargetG = carbsTargetG
        self.fatTargetG = fatTargetG
        self.intent = intent
        self.pace = pace
        self.activityLevel = activityLevel
        self.createdDate = createdDate
    }
}

nonisolated enum GoalIntent: String, Codable, CaseIterable, Sendable {
    case lose
    case maintain
    case gain
    
    var label: String {
        switch self {
        case .lose: return "Gå ned i vekt"
        case .maintain: return "Holde vekten"
        case .gain: return "Gå opp i vekt"
        }
    }
}

nonisolated enum GoalPace: String, Codable, CaseIterable, Sendable {
    case calm
    case standard
    case fast
    
    var label: String {
        switch self {
        case .calm: return "Rolig"
        case .standard: return "Standard"
        case .fast: return "Rask"
        }
    }
    
    var note: String? {
        switch self {
        case .fast: return "Større justering – ikke tilpasset alle"
        default: return nil
        }
    }
}

// MARK: - Products

nonisolated struct Product: Codable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let brand: String?
    let category: String?
    let barcodeEan: String?
    let source: String // "matvaretabellen", "openfoodfacts", "user", "shared"
    let kind: ProductKind
    
    // Nutrition per 100g
    let caloriesPer100g: Float
    let proteinGPer100g: Float
    let carbsGPer100g: Float
    let fatGPer100g: Float
    let sugarGPer100g: Float?
    let fiberGPer100g: Float?
    let sodiumMgPer100g: Int?
    
    let localImageData: Data?
    let imageUrl: String?
    let standardPortions: [StandardPortion]?
    let servings: [ServingOption]?
    let nutritionSource: NutritionSource
    let imageSource: ImageSource
    let verificationStatus: VerificationStatus
    let confidenceScore: Double?
    let isVerified: Bool
    let createdAt: Date
    let externalID: String?
    let manualNutritionInput: ManualNutritionInput?
    let nutritionBasis: NutritionBasis?
    let sourceUpdatedAt: Date?
    let sourceRevision: Int?
    let sourceSchemaVersion: Int?
    let fetchedAt: Date?
    let nutriScoreInfo: ProductNutriScoreInfo?
    let processingInfo: ProductProcessingInfo?
    let dataQualityWarnings: [String]?
    
    // Local flags
    var isSynced: Bool = true
    
    init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        category: String? = nil,
        barcodeEan: String? = nil,
        source: String = "user",
        kind: ProductKind = .packaged,
        caloriesPer100g: Float,
        proteinGPer100g: Float,
        carbsGPer100g: Float,
        fatGPer100g: Float,
        sugarGPer100g: Float? = nil,
        fiberGPer100g: Float? = nil,
        sodiumMgPer100g: Int? = nil,
        localImageData: Data? = nil,
        imageUrl: String? = nil,
        standardPortions: [StandardPortion]? = nil,
        servings: [ServingOption]? = nil,
        nutritionSource: NutritionSource = .user,
        imageSource: ImageSource = .user,
        verificationStatus: VerificationStatus = .unverified,
        confidenceScore: Double? = nil,
        isVerified: Bool = false,
        createdAt: Date = Date(),
        externalID: String? = nil,
        manualNutritionInput: ManualNutritionInput? = nil,
        nutritionBasis: NutritionBasis? = nil,
        sourceUpdatedAt: Date? = nil,
        sourceRevision: Int? = nil,
        sourceSchemaVersion: Int? = nil,
        fetchedAt: Date? = nil,
        nutriScoreInfo: ProductNutriScoreInfo? = nil,
        processingInfo: ProductProcessingInfo? = nil,
        dataQualityWarnings: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.category = category
        self.barcodeEan = barcodeEan
        self.source = source
        self.kind = kind
        self.caloriesPer100g = caloriesPer100g
        self.proteinGPer100g = proteinGPer100g
        self.carbsGPer100g = carbsGPer100g
        self.fatGPer100g = fatGPer100g
        self.sugarGPer100g = sugarGPer100g
        self.fiberGPer100g = fiberGPer100g
        self.sodiumMgPer100g = sodiumMgPer100g
        self.localImageData = localImageData
        self.imageUrl = imageUrl
        self.standardPortions = standardPortions
        self.servings = servings
        self.nutritionSource = nutritionSource
        self.imageSource = imageSource
        self.verificationStatus = verificationStatus
        self.confidenceScore = confidenceScore
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.externalID = externalID
        self.manualNutritionInput = manualNutritionInput
        self.nutritionBasis = nutritionBasis
        self.sourceUpdatedAt = sourceUpdatedAt
        self.sourceRevision = sourceRevision
        self.sourceSchemaVersion = sourceSchemaVersion
        self.fetchedAt = fetchedAt
        self.nutriScoreInfo = nutriScoreInfo
        self.processingInfo = processingInfo
        self.dataQualityWarnings = dataQualityWarnings
    }

    /// Stable local identity for read-only catalog rows. Version 8 marks the
    /// UUID as an application-defined deterministic value.
    static func catalogID(source: String, externalID: String) -> UUID {
        let normalized = "\(source.lowercased()):\(externalID.lowercased())"
        var bytes = Array(SHA256.hash(data: Data(normalized.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x80
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
    
    nonisolated var amountUnit: AmountUnit {
        (nutritionBasis ?? .per100g).amountUnit
    }

    // Nutrition values use the product's documented per-100 g or per-100 ml basis.
    // Keep the calculated values exact; presentation is responsible for rounding.
    func calculateNutrition(forAmount amount: Float) -> NutritionBreakdown {
        NutritionCalculator.calculated(
            per100: NutritionBreakdown(
                calories: caloriesPer100g,
                protein: proteinGPer100g,
                carbs: carbsGPer100g,
                fat: fatGPer100g
            ),
            amount: amount
        )
    }
}

// Preserve original input alongside normalized values locally and in product sync.
nonisolated struct ManualNutritionInput: Codable, Sendable {
    let basis: ManualNutritionBasis
    let amount: Double
    let unit: AmountUnit
    let label: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

nonisolated enum ManualNutritionBasis: String, Codable, CaseIterable, Sendable {
    case per100g, per100ml, serving

    var title: String {
        switch self {
        case .per100g: "100 g"
        case .per100ml: "100 ml"
        case .serving: "Porsjon/stykk"
        }
    }
}

nonisolated enum NutritionBasis: String, Codable, Sendable {
    case per100g
    case per100ml

    nonisolated var amountUnit: AmountUnit {
        switch self {
        case .per100g: return .grams
        case .per100ml: return .milliliters
        }
    }
}

nonisolated enum AmountUnit: String, Codable, CaseIterable, Sendable {
    case grams = "g"
    case milliliters = "ml"

    nonisolated var spokenName: String {
        switch self {
        case .grams: return "gram"
        case .milliliters: return "milliliter"
        }
    }
}

nonisolated struct StandardPortion: Codable, Hashable, Sendable {
    let label: String
    let grams: Double
}

nonisolated struct ServingOption: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let label: String
    let grams: Double
    let unit: AmountUnit?
    let source: ServingSource
    let isDefaultSuggestion: Bool
    let kind: ServingKind?
    let shortLabel: String?
    
    init(
        id: UUID = UUID(),
        label: String,
        grams: Double,
        unit: AmountUnit = .grams,
        source: ServingSource,
        isDefaultSuggestion: Bool = false,
        kind: ServingKind? = nil,
        shortLabel: String? = nil
    ) {
        self.id = id
        self.label = label
        self.grams = grams
        self.unit = unit
        self.source = source
        self.isDefaultSuggestion = isDefaultSuggestion
        self.kind = kind
        self.shortLabel = shortLabel
    }

    nonisolated var amountUnit: AmountUnit { unit ?? .grams }
}

nonisolated enum ServingSource: String, Codable, Sendable {
    case openFoodFacts
    case heuristic
    case user
}

nonisolated struct NutritionBreakdown: Codable, Sendable {
    let calories: Float
    let protein: Float
    let carbs: Float
    let fat: Float
}

nonisolated struct ProductMatchMapping: Codable, Sendable {
    let barcode: String
    let matvaretabellenId: String
    let matchedName: String
    let confidenceScore: Double
    let updatedAt: Date
    let caloriesPer100g: Float
    let proteinGPer100g: Float
    let carbsGPer100g: Float
    let fatGPer100g: Float
    let sugarGPer100g: Float?
    let fiberGPer100g: Float?
    let sodiumMgPer100g: Int?
    let category: String?
}

nonisolated enum NutritionSource: String, Codable, Sendable {
    case matvaretabellen
    case openFoodFacts
    case user
}

nonisolated enum ImageSource: String, Codable, Sendable {
    case openFoodFacts
    case user
    case none
}

nonisolated enum VerificationStatus: String, Codable, Sendable {
    case verified
    case unverified
    case suggestedMatch
}

nonisolated enum ProductKind: String, Codable, Sendable {
    case packaged
    case genericFood
}

nonisolated struct WeightEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let date: Date // date-only
    let weightKg: Double
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        date: Date,
        weightKg: Double,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = Calendar.current.startOfDay(for: date)
        self.weightKg = weightKg
        self.createdAt = createdAt
    }
}

nonisolated struct PersonalDetails: Codable, Sendable {
    var displayName: String?
    var weightKg: Double?
    var heightCm: Double?
    var birthDate: Date?
    var gender: GenderOption?
    var activityLevel: ActivityLevel?
    
    static let empty = PersonalDetails()
}

nonisolated enum GenderOption: String, Codable, CaseIterable, Sendable {
    case kvinne
    case mann
    case annet
    case ikkeOppgi
    
    var label: String {
        switch self {
        case .kvinne: return "Kvinne"
        case .mann: return "Mann"
        case .annet: return "Annet"
        case .ikkeOppgi: return "Ønsker ikke å oppgi"
        }
    }
}

nonisolated enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case lav
    case moderat
    case hoy
    case veldigHoy
    case ikkeOppgi
    
    var label: String {
        switch self {
        case .lav: return "Lav"
        case .moderat: return "Moderat"
        case .hoy: return "Høy"
        case .veldigHoy: return "Veldig høy"
        case .ikkeOppgi: return "Ønsker ikke å oppgi"
        }
    }
    
    var description: String {
        switch self {
        case .lav:
            return "Mest stillesitting. Lite hverdagsbevegelse."
        case .moderat:
            return "Noe daglig bevegelse. En del gåing/standing."
        case .hoy:
            return "Mye bevegelse gjennom dagen. Ofte aktiv."
        case .veldigHoy:
            return "Fysisk krevende dager. Høyt tempo og belastning."
        case .ikkeOppgi:
            return "Ønsker ikke å oppgi."
        }
    }
}

// MARK: - Logs

nonisolated struct FoodLog: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let productId: UUID
    let mealType: String // "frokost", "lunsj", "middag", "snacks"
    let amountG: Float // exact, no rounding
    let amountUnit: AmountUnit?
    let portionSelection: PortionSelection?
    let loggedDate: Date // date-only
    let loggedTime: Date // full timestamp
    
    // Calculated (denormalized)
    let calories: Float
    let proteinG: Float
    let carbsG: Float
    let fatG: Float
    
    let createdAt: Date
    let isSynced: Bool
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        productId: UUID,
        mealType: String,
        amountG: Float,
        amountUnit: AmountUnit = .grams,
        portionSelection: PortionSelection? = nil,
        loggedDate: Date,
        loggedTime: Date = Date(),
        calories: Float,
        proteinG: Float,
        carbsG: Float,
        fatG: Float,
        createdAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.productId = productId
        self.mealType = mealType
        self.amountG = amountG
        self.amountUnit = amountUnit
        self.portionSelection = portionSelection
        self.loggedDate = loggedDate
        self.loggedTime = loggedTime
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.createdAt = createdAt
        self.isSynced = isSynced
    }

    nonisolated var resolvedAmountUnit: AmountUnit { amountUnit ?? .grams }
}

// MARK: - Saved meals

/// A user-owned, reusable meal template. Using it creates independent FoodLog values.
nonisolated struct SavedMeal: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    var name: String
    var suggestedMealType: String?
    var items: [SavedMealItem]
    /// Local-only JPEG; deliberately excluded from sync payloads.
    var localImageData: Data?
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        suggestedMealType: String? = nil,
        items: [SavedMealItem],
        localImageData: Data? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.suggestedMealType = suggestedMealType
        self.items = items
        self.localImageData = localImageData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Keeps the exact amount, nutrition basis and source that the user approved.
nonisolated struct SavedMealItem: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let productId: UUID
    let productName: String
    var amountG: Float
    var amountUnit: AmountUnit?
    var portionSelection: PortionSelection?
    var calories: Float
    var proteinG: Float
    var carbsG: Float
    var fatG: Float
    let nutritionSource: NutritionSource
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        productId: UUID,
        productName: String,
        amountG: Float,
        amountUnit: AmountUnit = .grams,
        portionSelection: PortionSelection? = nil,
        calories: Float,
        proteinG: Float,
        carbsG: Float,
        fatG: Float,
        nutritionSource: NutritionSource,
        sortIndex: Int
    ) {
        self.id = id
        self.productId = productId
        self.productName = productName
        self.amountG = amountG
        self.amountUnit = amountUnit
        self.portionSelection = portionSelection
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.nutritionSource = nutritionSource
        self.sortIndex = sortIndex
    }

    nonisolated var resolvedAmountUnit: AmountUnit { amountUnit ?? .grams }
}

// MARK: - Favorites

nonisolated struct Favorite: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let productId: UUID
    let createdAt: Date
    let isSynced: Bool
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        productId: UUID,
        createdAt: Date = Date(),
        isSynced: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.productId = productId
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}

// MARK: - Scan History

nonisolated struct ScanHistory: Codable, Identifiable, Sendable {
    let id: UUID
    let userId: UUID
    let productId: UUID
    let scannedAt: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        productId: UUID,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.productId = productId
        self.scannedAt = scannedAt
    }
}

// MARK: - Daily Summary

nonisolated struct DailySummary: Sendable {
    let date: Date
    let totalCalories: Float
    let totalProtein: Float
    let totalCarbs: Float
    let totalFat: Float
    let logs: [FoodLog]
    
    var logsByMeal: [String: [FoodLog]] {
        Dictionary(grouping: logs) { $0.mealType }
    }
}

nonisolated enum NutritionCalculator: Sendable {
    static let maximumAmount: Float = 10_000

    static func validatedCalculation(
        per100: NutritionBreakdown,
        amount: Float
    ) -> NutritionBreakdown? {
        guard isValidAmount(amount), isValidBreakdown(per100) else { return nil }
        let result = calculated(per100: per100, amount: amount)
        return isValidBreakdown(result) ? result : nil
    }

    static func calculated(per100: NutritionBreakdown, amount: Float) -> NutritionBreakdown {
        let multiplier = amount / 100
        return NutritionBreakdown(
            calories: per100.calories * multiplier,
            protein: per100.protein * multiplier,
            carbs: per100.carbs * multiplier,
            fat: per100.fat * multiplier
        )
    }

    static func totals(for logs: [FoodLog]) -> NutritionBreakdown {
        logs.reduce(NutritionBreakdown(calories: 0, protein: 0, carbs: 0, fat: 0)) { total, log in
            NutritionBreakdown(
                calories: total.calories + log.calories,
                protein: total.protein + log.proteinG,
                carbs: total.carbs + log.carbsG,
                fat: total.fat + log.fatG
            )
        }
    }

    static func scaledSnapshot(
        calories: Float,
        protein: Float,
        carbs: Float,
        fat: Float,
        from originalAmount: Float,
        to amount: Float
    ) -> NutritionBreakdown? {
        guard isValidAmount(originalAmount),
              isValidAmount(amount),
              isValidBreakdown(NutritionBreakdown(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
              )) else { return nil }
        let factor = amount / originalAmount
        let result = NutritionBreakdown(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor
        )
        guard [result.calories, result.protein, result.carbs, result.fat].allSatisfy({ $0.isFinite && $0 >= 0 }) else {
            return nil
        }
        return result
    }

    private static func isValidAmount(_ amount: Float) -> Bool {
        amount.isFinite && amount > 0 && amount <= maximumAmount
    }

    private static func isValidBreakdown(_ breakdown: NutritionBreakdown) -> Bool {
        [breakdown.calories, breakdown.protein, breakdown.carbs, breakdown.fat]
            .allSatisfy { $0.isFinite && $0 >= 0 }
    }
}

nonisolated enum NutritionDisplay: Sendable {
    static func wholeCalories(_ value: Float) -> Int {
        Int(value.rounded())
    }

    static func wholeGrams(_ value: Float) -> Int {
        Int(value.rounded())
    }
}

// MARK: - Sync

nonisolated enum SyncEventStatus: String, Sendable {
    case pending
    case inFlight
    case acked
    case deadLetter
    case quarantined
}

nonisolated struct SyncEvent: Sendable {
    let eventId: UUID
    let type: String
    let createdAt: Date
    let entityId: String?
    let schemaVersion: Int
    let payload: Data
    let status: SyncEventStatus
    let attemptCount: Int
    let lastAttemptAt: Date?
    let nextRetryAt: Date?
    let lastError: String?
    /// Local routing metadata. It is never included in the wire envelope.
    let ownerUserId: UUID?
}

nonisolated struct SyncQueueStatus: Equatable, Sendable {
    let pendingCount: Int
    let inFlightCount: Int
    let failedCount: Int
    let nextRetryAt: Date?

    static let empty = SyncQueueStatus(
        pendingCount: 0,
        inFlightCount: 0,
        failedCount: 0,
        nextRetryAt: nil
    )

    var unsyncedCount: Int { pendingCount + inFlightCount + failedCount }
}

nonisolated struct SyncFailureSummary: Identifiable, Equatable, Sendable {
    let id: UUID
    let type: String
    let message: String
    let createdAt: Date
}

nonisolated enum NetworkAvailability: Equatable, Sendable {
    case unknown
    case offline
    case online
}

// MARK: - Auth State

nonisolated enum AuthState: Sendable {
    case notAuthenticated
    case authenticating
    case local(user: User)
    case authenticated(user: User)
    case onboarding(user: User)
    case awaitingLocalDataLink(localUser: User, accountUser: User)
    case error(String)
}

nonisolated struct LocalDataSummary: Equatable, Sendable {
    let logs: Int
    let goals: Int
    let favorites: Int
    let scans: Int
    let weights: Int
    var waterGlasses: Int = 0
    let savedMeals: Int
    let products: Int

    static let empty = LocalDataSummary(logs: 0, goals: 0, favorites: 0, scans: 0, weights: 0, savedMeals: 0, products: 0)

    var totalCount: Int { logs + goals + favorites + scans + weights + waterGlasses + savedMeals + products }
    var hasData: Bool { totalCount > 0 }
}

/// One user-recorded glass; no assumed volume or nutrition values.
nonisolated struct WaterGlass: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var userId: UUID
    var date: Date
    var createdAt = Date()
}

/// Read-only catalog information; no classification is inferred locally.
nonisolated struct ProductProcessingInfo: Codable, Sendable, Equatable {
    let novaGroup: Int?
    let markers: [String: [[String]]]
    let ingredients: String?

    var groupTitle: String {
        switch novaGroup {
        case 1: return "Minimalt bearbeidet · NOVA 1"
        case 2: return "Bearbeidet matlagingsingrediens · NOVA 2"
        case 3: return "Bearbeidet · NOVA 3"
        case 4: return "Ultraprosessert · NOVA 4"
        default: return "Bearbeidingsgrad ikke tilgjengelig"
        }
    }

    var classificationText: String? {
        guard let novaGroup, (1...4).contains(novaGroup) else { return nil }
        return novaGroup == 4
            ? "Klassifisert som ultraprosessert av Open Food Facts."
            : "Ikke klassifisert som ultraprosessert av Open Food Facts."
    }

    private var groupMarkers: [[String]] {
        guard let novaGroup else { return [] }
        return markers[String(novaGroup)] ?? []
    }

    private func markerName(_ marker: [String]) -> String? {
        guard marker.count == 2, marker[0] == "ingredients" else { return nil }
        return ["en:salt": "salt", "en:sugar": "sukker"][marker[1]]
    }

    var hasUntranslatedMarkers: Bool {
        groupMarkers.contains { markerName($0) == nil }
    }

    var markerNames: [String] {
        Set(groupMarkers.compactMap(markerName)).sorted()
    }
}

/// Source-provided grade, never calculated from local nutrition values.
nonisolated struct ProductNutriScoreInfo: Codable, Sendable, Equatable {
    let grade: String
    let version: String?
    let calculation: NutriScoreCalculation?

    /// Only recognized source algorithm versions select a logo variant.
    var imageAssetName: String? {
        guard ["A", "B", "C", "D", "E"].contains(grade),
              let version, ["2021", "2023"].contains(version) else { return nil }
        return "NutriScore-\(version)-\(grade)"
    }

    init?(grade: String?, version: String?, calculation: NutriScoreCalculation? = nil) {
        guard let normalized = grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
              ["A", "B", "C", "D", "E"].contains(normalized) else { return nil }
        self.grade = normalized
        self.calculation = calculation
        let trimmedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.version = trimmedVersion?.isEmpty == false ? trimmedVersion : nil
    }
}

nonisolated struct NutriScoreCalculation: Codable, Sendable, Equatable {
    var nutritionBasis: NutritionBasis? = nil
    let positive: [NutriScoreComponent]
    let negative: [NutriScoreComponent]
    let positivePoints: Int?
    let positiveMaximum: Int?
    let negativePoints: Int?
    let negativeMaximum: Int?
    let estimated: Bool
    let preparation: String?
    let proteinExclusionReason: String?
}

nonisolated struct NutriScoreComponent: Codable, Sendable, Equatable {
    let id: String
    let value: Double?
    let unit: String?
    let points: Int?
    let points_max: Int?
}
