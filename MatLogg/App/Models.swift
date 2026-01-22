import Foundation

// MARK: - User & Auth

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let firstName: String
    let lastName: String
    let authProvider: String // "apple", "google", "email"
    let createdAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - Goals

struct Goal: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let goalType: String // "weight_loss", "maintain", "gain"
    let dailyCalories: Int
    let proteinTargetG: Float
    let carbsTargetG: Float
    let fatTargetG: Float
    let createdDate: Date
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        goalType: String,
        dailyCalories: Int,
        proteinTargetG: Float,
        carbsTargetG: Float,
        fatTargetG: Float,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.goalType = goalType
        self.dailyCalories = dailyCalories
        self.proteinTargetG = proteinTargetG
        self.carbsTargetG = carbsTargetG
        self.fatTargetG = fatTargetG
        self.createdDate = createdDate
    }
}

// MARK: - Products

struct Product: Codable, Identifiable {
    let id: UUID
    let name: String
    let brand: String?
    let category: String?
    let barcodeEan: String?
    let source: String // "matvaretabellen", "openfoodfacts", "user", "shared"
    let kind: ProductKind
    
    // Nutrition per 100g
    let caloriesPer100g: Int
    let proteinGPer100g: Float
    let carbsGPer100g: Float
    let fatGPer100g: Float
    let sugarGPer100g: Float?
    let fiberGPer100g: Float?
    let sodiumMgPer100g: Int?
    
    let imageUrl: String?
    let standardPortions: [StandardPortion]?
    let nutritionSource: NutritionSource
    let imageSource: ImageSource
    let verificationStatus: VerificationStatus
    let confidenceScore: Double?
    let isVerified: Bool
    let createdAt: Date
    
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
        caloriesPer100g: Int,
        proteinGPer100g: Float,
        carbsGPer100g: Float,
        fatGPer100g: Float,
        sugarGPer100g: Float? = nil,
        fiberGPer100g: Float? = nil,
        sodiumMgPer100g: Int? = nil,
        imageUrl: String? = nil,
        standardPortions: [StandardPortion]? = nil,
        nutritionSource: NutritionSource = .user,
        imageSource: ImageSource = .user,
        verificationStatus: VerificationStatus = .unverified,
        confidenceScore: Double? = nil,
        isVerified: Bool = false,
        createdAt: Date = Date()
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
        self.imageUrl = imageUrl
        self.standardPortions = standardPortions
        self.nutritionSource = nutritionSource
        self.imageSource = imageSource
        self.verificationStatus = verificationStatus
        self.confidenceScore = confidenceScore
        self.isVerified = isVerified
        self.createdAt = createdAt
    }
    
    // Calculate nutrition for given amount
    func calculateNutrition(forGrams grams: Float) -> NutritionBreakdown {
        let multiplier = grams / 100.0
        return NutritionBreakdown(
            calories: Int(Float(caloriesPer100g) * multiplier),
            protein: proteinGPer100g * multiplier,
            carbs: carbsGPer100g * multiplier,
            fat: fatGPer100g * multiplier
        )
    }
}

struct StandardPortion: Codable, Hashable {
    let label: String
    let grams: Double
}

struct NutritionBreakdown: Codable {
    let calories: Int
    let protein: Float
    let carbs: Float
    let fat: Float
}

struct ProductMatchMapping: Codable {
    let barcode: String
    let matvaretabellenId: String
    let matchedName: String
    let confidenceScore: Double
    let updatedAt: Date
    let caloriesPer100g: Int
    let proteinGPer100g: Float
    let carbsGPer100g: Float
    let fatGPer100g: Float
    let sugarGPer100g: Float?
    let fiberGPer100g: Float?
    let sodiumMgPer100g: Int?
    let category: String?
}

enum NutritionSource: String, Codable {
    case matvaretabellen
    case openFoodFacts
    case user
}

enum ImageSource: String, Codable {
    case openFoodFacts
    case user
    case none
}

enum VerificationStatus: String, Codable {
    case verified
    case unverified
    case suggestedMatch
}

enum ProductKind: String, Codable {
    case packaged
    case genericFood
}

struct WeightEntry: Codable, Identifiable {
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

struct PersonalDetails: Codable {
    var weightKg: Double?
    var heightCm: Double?
    var birthDate: Date?
    var gender: GenderOption?
    var activityLevel: ActivityLevel?
    
    static let empty = PersonalDetails()
}

enum GenderOption: String, Codable, CaseIterable {
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

enum ActivityLevel: String, Codable, CaseIterable {
    case lav
    case moderat
    case hoy
    case ikkeOppgi
    
    var label: String {
        switch self {
        case .lav: return "Lav"
        case .moderat: return "Moderat"
        case .hoy: return "Høy"
        case .ikkeOppgi: return "Ønsker ikke å oppgi"
        }
    }
}

// MARK: - Logs

struct FoodLog: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: UUID
    let mealType: String // "frokost", "lunsj", "middag", "snacks"
    let amountG: Float // exact, no rounding
    let loggedDate: Date // date-only
    let loggedTime: Date // full timestamp
    
    // Calculated (denormalized)
    let calories: Int
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
        loggedDate: Date,
        loggedTime: Date = Date(),
        calories: Int,
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
        self.loggedDate = loggedDate
        self.loggedTime = loggedTime
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.createdAt = createdAt
        self.isSynced = isSynced
    }
}

// MARK: - Favorites

struct Favorite: Codable, Identifiable {
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

struct ScanHistory: Codable, Identifiable {
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

struct DailySummary {
    let date: Date
    let totalCalories: Int
    let totalProtein: Float
    let totalCarbs: Float
    let totalFat: Float
    let logs: [FoodLog]
    
    var logsByMeal: [String: [FoodLog]] {
        Dictionary(grouping: logs) { $0.mealType }
    }
}

// MARK: - Auth State

enum AuthState {
    case notAuthenticated
    case authenticating
    case authenticated(user: User)
    case onboarding(user: User)
    case error(String)
}
