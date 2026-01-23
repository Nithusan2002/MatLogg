import Foundation

struct GoalCalculationInput {
    let weightKg: Double?
    let heightCm: Double?
    let ageYears: Int?
    let gender: GenderOption?
    let activity: ActivityLevel
    let intent: GoalIntent
    let pace: GoalPace
}

struct GoalCalculationResult {
    let suggestedCalories: Int
    let baselineCalories: Int
}

enum GoalCalculator {
    static func calculateSuggestion(input: GoalCalculationInput) -> GoalCalculationResult {
        let baseline = baselineCalories(activity: input.activity)
        let tdee = calculateTDEE(input: input) ?? baseline
        let adjusted = tdee + intentAdjustment(intent: input.intent, pace: input.pace)
        let contextClamped = clampRelative(to: tdee, intent: input.intent, value: adjusted)
        let clamped = clampCalories(contextClamped)
        return GoalCalculationResult(
            suggestedCalories: clamped,
            baselineCalories: tdee
        )
    }
    
    static func calculateMacros(kcal: Int, preset: MacroPreset, custom: MacroTargets? = nil) -> MacroTargets {
        switch preset {
        case .balanced:
            return macrosFromPercent(kcal: kcal, proteinPct: 0.30, carbsPct: 0.40, fatPct: 0.30)
        case .proteinFocus:
            return macrosFromPercent(kcal: kcal, proteinPct: 0.35, carbsPct: 0.30, fatPct: 0.35)
        case .carbFocus:
            return macrosFromPercent(kcal: kcal, proteinPct: 0.25, carbsPct: 0.50, fatPct: 0.25)
        case .custom:
            return custom ?? macrosFromPercent(kcal: kcal, proteinPct: 0.30, carbsPct: 0.40, fatPct: 0.30)
        }
    }
    
    static func clampCalories(_ value: Int) -> Int {
        min(max(value, 1200), 4500)
    }
    
    static func roundedDisplay(_ value: Int) -> Int {
        Int((Double(value) / 10.0).rounded() * 10.0)
    }
    
    private static func calculateTDEE(input: GoalCalculationInput) -> Int? {
        guard let weight = input.weightKg,
              let height = input.heightCm,
              let age = input.ageYears else {
            return nil
        }
        
        let genderOffset: Double
        switch input.gender {
        case .mann:
            genderOffset = 5
        case .kvinne:
            genderOffset = -161
        default:
            genderOffset = 0
        }
        
        let bmr = (10 * weight) + (6.25 * height) - (5 * Double(age)) + genderOffset
        let factor = activityFactor(input.activity)
        return Int((bmr * factor).rounded())
    }
    
    private static func activityFactor(_ level: ActivityLevel) -> Double {
        switch level {
        case .lav:
            return 1.2
        case .moderat:
            return 1.375
        case .hoy:
            return 1.55
        case .veldigHoy:
            return 1.725
        case .ikkeOppgi:
            return 1.375
        }
    }
    
    private static func baselineCalories(activity: ActivityLevel) -> Int {
        switch activity {
        case .lav:
            return 1800
        case .moderat:
            return 2000
        case .hoy:
            return 2300
        case .veldigHoy:
            return 2600
        case .ikkeOppgi:
            return 2000
        }
    }
    
    private static func intentAdjustment(intent: GoalIntent, pace: GoalPace) -> Int {
        switch intent {
        case .maintain:
            return 0
        case .lose:
            switch pace {
            case .calm: return -250
            case .standard: return -400
            case .fast: return -600
            }
        case .gain:
            switch pace {
            case .calm: return 200
            case .standard: return 300
            case .fast: return 450
            }
        }
    }
    
    private static func clampRelative(to tdee: Int, intent: GoalIntent, value: Int) -> Int {
        switch intent {
        case .maintain:
            return value
        case .lose:
            let minByPercent = Int(Double(tdee) * 0.75)
            let minByOffset = tdee - 600
            let lowerBound = max(minByPercent, minByOffset)
            return max(value, lowerBound)
        case .gain:
            let maxByPercent = Int(Double(tdee) * 1.25)
            let maxByOffset = tdee + 450
            let upperBound = min(maxByPercent, maxByOffset)
            return min(value, upperBound)
        }
    }
    
    private static func macrosFromPercent(kcal: Int, proteinPct: Double, carbsPct: Double, fatPct: Double) -> MacroTargets {
        let proteinG = (Double(kcal) * proteinPct) / 4.0
        let carbsG = (Double(kcal) * carbsPct) / 4.0
        let fatG = (Double(kcal) * fatPct) / 9.0
        return MacroTargets(
            proteinG: Float(proteinG),
            carbsG: Float(carbsG),
            fatG: Float(fatG)
        )
    }
}

enum MacroPreset: String, CaseIterable {
    case balanced
    case proteinFocus
    case carbFocus
    case custom
    
    var label: String {
        switch self {
        case .balanced: return "Balansert (anbefalt)"
        case .proteinFocus: return "Protein-fokus"
        case .carbFocus: return "Karbo-fokus"
        case .custom: return "Tilpass"
        }
    }
}

struct MacroTargets {
    let proteinG: Float
    let carbsG: Float
    let fatG: Float
}
