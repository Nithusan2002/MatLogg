import Foundation
import Combine

/// A disposable editing session. Only an explicit save writes through the repository.
@MainActor
final class DailyGoalsViewModel: ObservableObject {
    enum Field: Hashable { case calories, protein, carbs, fat }

    @Published var calories = ""
    @Published var protein = ""
    @Published var carbs = ""
    @Published var fat = ""
    @Published private(set) var errors: [Field: String] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false
    @Published private(set) var didSave = false
    @Published private(set) var hasGoal = false

    private let repository: any GoalRepository
    private let onSaved: (Goal) -> Void
    private var original: Goal?
    private var userId: UUID?
    private var suggestion: GoalSuggestion?

    init(repository: any GoalRepository, onSaved: @escaping (Goal) -> Void = { _ in }) {
        self.repository = repository
        self.onSaved = onSaved
    }

    func begin(goal: Goal?, userId: UUID?) {
        guard !isSaving else { return }
        original = goal?.userId == userId ? goal : nil
        self.userId = userId
        hasGoal = original != nil
        calories = original.map { String($0.dailyCalories) } ?? ""
        protein = original.map { Self.display($0.proteinTargetG) } ?? ""
        carbs = original.map { Self.display($0.carbsTargetG) } ?? ""
        fat = original.map { Self.display($0.fatTargetG) } ?? ""
        suggestion = nil
        errors = [:]
        errorMessage = nil
        didSave = false
    }

    func discard() {
        begin(goal: nil, userId: nil)
    }

    func apply(_ suggestion: GoalSuggestion) {
        guard !isSaving else { return }
        self.suggestion = suggestion
        calories = String(suggestion.calories)
        protein = Self.display(suggestion.macros.proteinG)
        carbs = Self.display(suggestion.macros.carbsG)
        fat = Self.display(suggestion.macros.fatG)
        errors = [:]
        errorMessage = nil
    }

    @discardableResult
    func save(hideGoals: Bool, hideCalories: Bool, safeModeEnabled: Bool) async -> Bool {
        guard !isSaving, !didSave else { return false }
        errors = [:]
        errorMessage = nil
        guard !hideGoals, !safeModeEnabled else { return false }
        guard let userId else {
            errorMessage = "Åpne skjermen på nytt når du er logget inn."
            return false
        }
        // Hidden calories are never changed by an existing draft or suggestion.
        let kcal = hideCalories ? original?.dailyCalories : Int(calories.trimmingCharacters(in: .whitespacesAndNewlines))
        if kcal == nil || (!hideCalories && !GoalCalculator.calorieRange.contains(kcal!)) {
            if hideCalories {
                errorMessage = "Vis kalorier i Innstillinger for å sette opp et nytt mål."
            } else {
                errors[.calories] = "Skriv et heltall mellom 1200 og 4500 kcal."
            }
        }
        let p = macro(protein, field: .protein)
        let c = macro(carbs, field: .carbs)
        let f = macro(fat, field: .fat)
        guard errors.isEmpty, errorMessage == nil, let kcal, let p, let c, let f else { return false }
        let acceptedSuggestion = hideCalories ? nil : suggestion
        let intent = acceptedSuggestion?.intent ?? original?.intent
        let goalType = acceptedSuggestion.map { Self.goalType($0.intent) } ?? original?.goalType ?? "maintain"
        let pace = acceptedSuggestion?.pace ?? original?.pace
        let activity = acceptedSuggestion?.activity ?? original?.activityLevel
        if let original,
           original.dailyCalories == kcal, original.proteinTargetG == p,
           original.carbsTargetG == c, original.fatTargetG == f,
           original.goalType == goalType, original.intent == intent,
           original.pace == pace, original.activityLevel == activity {
            didSave = true
            return true
        }
        let goal = Goal(userId: userId, goalType: goalType, dailyCalories: kcal,
                        proteinTargetG: p, carbsTargetG: c, fatTargetG: f,
                        intent: intent, pace: pace, activityLevel: activity,
                        safeModeEnabled: safeModeEnabled)
        isSaving = true
        defer { isSaving = false }
        do {
            try await repository.saveGoal(goal)
            original = goal
            hasGoal = true
            onSaved(goal)
            didSave = true
            return true
        } catch {
            errorMessage = "Kunne ikke lagre målene. Endringene dine er beholdt. Prøv igjen."
            return false
        }
    }

    private func macro(_ text: String, field: Field) -> Float? {
        guard let value = Float(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")),
              value.isFinite, value >= 0,
              // Keep downstream Int display conversions representable, including legacy screens.
              Double(value) < Double(Int.max) else {
            errors[field] = "Skriv et gyldig antall gram, 0 eller mer."
            return nil
        }
        return value
    }

    private static func display(_ value: Float) -> String {
        String(value).replacingOccurrences(of: ".", with: ",")
    }

    private static func goalType(_ intent: GoalIntent) -> String {
        switch intent {
        case .lose: return "weight_loss"
        case .maintain: return "maintain"
        case .gain: return "gain"
        }
    }
}

struct GoalSuggestion {
    let calories: Int
    let macros: MacroTargets
    let intent: GoalIntent
    let pace: GoalPace
    let activity: ActivityLevel
}

/// Calculation-only wizard; opening, changing or cancelling it never writes data.
@MainActor
final class GoalSuggestionViewModel: ObservableObject {
    @Published var intent: GoalIntent
    @Published var pace: GoalPace
    @Published var activity: ActivityLevel
    @Published var preset: MacroPreset = .balanced
    @Published var showingResult = false
    private let details: PersonalDetails
    private let age: Int?

    init(goal: Goal?, details: PersonalDetails, now: Date = Date(), calendar: Calendar = .current) {
        intent = goal?.intent ?? (goal?.goalType == "weight_loss" ? .lose : goal?.goalType == "gain" ? .gain : .maintain)
        pace = goal?.pace ?? .calm
        activity = goal?.activityLevel ?? details.activityLevel ?? .moderat
        self.details = details
        age = details.birthDate.map { calendar.dateComponents([.year], from: $0, to: now).year ?? 0 }
    }

    var usesPersonalDetails: Bool {
        guard let weight = details.weightKg, let height = details.heightCm, let age else { return false }
        guard details.gender == .kvinne || details.gender == .mann else { return false }
        return weight.isFinite && height.isFinite
            && GoalCalculator.supportedWeightRange.contains(weight)
            && GoalCalculator.supportedHeightRange.contains(height)
            && GoalCalculator.supportedAgeRange.contains(age)
    }

    var unavailableReason: String? {
        if let age, !GoalCalculator.supportedAgeRange.contains(age) {
            return "Automatiske forslag er bare tilgjengelige for voksne. Du kan fortsatt angi egne mål."
        }
        return "Et personlig forslag krever gyldig vekt, høyde, fødselsdato og valg av kvinne- eller mannvarianten i beregningsformelen. Du kan fortsatt angi egne mål."
    }

    var suggestion: GoalSuggestion? {
        guard usesPersonalDetails else { return nil }
        let input = GoalCalculationInput(
            weightKg: details.weightKg,
            heightCm: details.heightCm,
            ageYears: age,
            gender: details.gender, activity: activity, intent: intent, pace: pace
        )
        guard let result = GoalCalculator.calculateSuggestion(input: input) else { return nil }
        let kcal = GoalCalculator.roundedDisplay(result.suggestedCalories)
        return GoalSuggestion(calories: kcal, macros: GoalCalculator.calculateMacros(kcal: kcal, preset: preset),
                              intent: intent, pace: pace, activity: activity)
    }
}
