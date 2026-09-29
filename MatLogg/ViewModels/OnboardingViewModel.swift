import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Hashable {
        case introduction
        case intent
        case goalSetup
        case personalDetails
        case result
        case macros
        case privacy
        case summary
    }

    enum IntentChoice: String, CaseIterable, Identifiable {
        case lose
        case maintain
        case gain
        case loggingOnly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .lose: return "Gå rolig ned i vekt"
            case .maintain: return "Holde vekten stabil"
            case .gain: return "Gå rolig opp i vekt"
            case .loggingOnly: return "Kun loggføring"
            }
        }

        var description: String {
            switch self {
            case .lose, .gain:
                return "Et valgfritt utgangspunkt som kan endres senere."
            case .maintain:
                return "Følg med på vanene dine over tid."
            case .loggingOnly:
                return "Registrer mat uten dagsmål eller målframdrift."
            }
        }

        var goalIntent: GoalIntent? {
            switch self {
            case .lose: return .lose
            case .maintain: return .maintain
            case .gain: return .gain
            case .loggingOnly: return nil
            }
        }
    }

    struct Completion {
        let goal: Goal?
        let personalDetails: PersonalDetails?
    }

    @Published private(set) var step: Step = .introduction
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published var intent: IntentChoice = .maintain
    @Published var pace: GoalPace = .calm
    @Published var activity: ActivityLevel = .moderat
    @Published var gender: GenderOption = .ikkeOppgi
    @Published var weightText = ""
    @Published var heightText = ""
    @Published var ageText = ""
    @Published var calorieTargetText = ""
    @Published var macroPreset: MacroPreset = .balanced
    @Published var proteinText = ""
    @Published var carbsText = ""
    @Published var fatText = ""
    @Published private(set) var isManualTarget = false
    @Published private(set) var attemptedResult = false
    @Published private(set) var attemptedMacros = false

    private let goalRepository: any GoalRepository
    private let personalDetailsStore: any PersonalDetailsStore
    private var history: [Step] = []
    private var activeUserId: UUID?
    private var initialDetails: PersonalDetails = .empty
    private var skipsGoalSetup = false

    init(
        goalRepository: any GoalRepository,
        personalDetailsStore: any PersonalDetailsStore
    ) {
        self.goalRepository = goalRepository
        self.personalDetailsStore = personalDetailsStore
    }

    convenience init(goalRepository: any GoalRepository) {
        self.init(
            goalRepository: goalRepository,
            personalDetailsStore: UserDefaultsPersonalDetailsStore()
        )
    }

    func begin(userId: UUID, goal: Goal?, details: PersonalDetails) {
        guard activeUserId != userId else { return }
        activeUserId = userId
        initialDetails = details
        step = .introduction
        history = []
        if let goalIntent = goal?.intent {
            switch goalIntent {
            case .lose: intent = .lose
            case .maintain: intent = .maintain
            case .gain: intent = .gain
            }
        } else {
            intent = .maintain
        }
        pace = goal?.pace ?? .calm
        activity = goal?.activityLevel ?? details.activityLevel ?? .moderat
        gender = details.gender ?? .ikkeOppgi
        weightText = Self.format(details.weightKg)
        heightText = Self.format(details.heightCm)
        ageText = Self.age(from: details.birthDate).map(String.init) ?? ""
        calorieTargetText = goal.map { String($0.dailyCalories) } ?? ""
        errorMessage = nil
        isManualTarget = goal != nil
        attemptedResult = false
        attemptedMacros = false
        skipsGoalSetup = false
    }

    func chooseQuickStart() {
        skipsGoalSetup = true
        intent = .loggingOnly
        go(to: .privacy)
    }

    func advance() {
        errorMessage = nil
        switch step {
        case .introduction:
            skipsGoalSetup = false
            go(to: .intent)
        case .intent:
            go(to: intent == .loggingOnly ? .privacy : .goalSetup)
        case .goalSetup:
            go(to: .personalDetails)
        case .personalDetails:
            prepareSuggestedTarget()
            go(to: .result)
        case .result:
            attemptedResult = true
            guard hasValidCalorieTarget else { return }
            go(to: .macros)
        case .macros:
            attemptedMacros = true
            guard hasValidMacros else { return }
            go(to: .privacy)
        case .privacy:
            go(to: .summary)
        case .summary:
            break
        }
    }

    func continueWithoutGoal() {
        skipsGoalSetup = true
        intent = .loggingOnly
        calorieTargetText = ""
        go(to: .privacy)
    }

    func useManualTarget() {
        isManualTarget = true
        calorieTargetText = ""
    }

    func continueWithManualTarget() {
        useManualTarget()
        go(to: .result)
    }

    func adjustCalories(by amount: Int) {
        guard let value = calorieTarget else { return }
        isManualTarget = true
        calorieTargetText = String(GoalCalculator.clampCalories(value + amount))
    }

    func back() {
        guard let previous = history.popLast() else { return }
        step = previous
        errorMessage = nil
        attemptedResult = false
        attemptedMacros = false
    }

    func edit(_ destination: Step) {
        go(to: destination)
    }

    func complete(userId: UUID) async -> Completion? {
        guard !isSaving, activeUserId == userId else { return nil }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        guard shouldCreateGoal else {
            return Completion(goal: nil, personalDetails: nil)
        }
        guard let goal = makeGoal(userId: userId) else {
            errorMessage = "Kontroller mål og næringsfordeling før du fullfører."
            return nil
        }

        let details = makePersonalDetails()
        do {
            try personalDetailsStore.save(details, userId: userId)
            try await goalRepository.saveGoal(goal)
            return Completion(goal: goal, personalDetails: details)
        } catch {
            errorMessage = "Kunne ikke fullføre oppsettet. Utfylte opplysninger er beholdt, og du kan prøve igjen. \(error.localizedDescription)"
            return nil
        }
    }

    var canGoBack: Bool { !history.isEmpty }

    var primaryButtonTitle: String {
        switch step {
        case .introduction: return "Sett opp min oversikt"
        case .intent, .goalSetup: return "Fortsett"
        case .personalDetails: return "Se estimert startpunkt"
        case .result: return "Bruk dette målet"
        case .macros: return "Se min oppsummering"
        case .privacy: return "Fortsett"
        case .summary: return "Lagre og gå til Hjem"
        }
    }

    var progressText: String? {
        guard step != .introduction else { return nil }
        let sequence = activeSequence
        guard let index = sequence.firstIndex(of: step) else { return nil }
        return "Steg \(index + 1) av \(sequence.count)"
    }

    var progressFraction: Double {
        let sequence = activeSequence
        guard let index = sequence.firstIndex(of: step), !sequence.isEmpty else { return 0 }
        return Double(index + 1) / Double(sequence.count)
    }

    var suggestion: Int? {
        guard let goalIntent = intent.goalIntent else { return nil }
        let input = GoalCalculationInput(
            weightKg: Self.parseNumber(weightText),
            heightCm: Self.parseNumber(heightText),
            ageYears: Int(ageText.filter(\.isNumber)),
            gender: gender == .ikkeOppgi ? nil : gender,
            activity: activity,
            intent: goalIntent,
            pace: pace
        )
        return GoalCalculator.calculateSuggestion(input: input).map {
            GoalCalculator.roundedDisplay($0.suggestedCalories)
        }
    }

    var calorieTarget: Int? {
        Int(calorieTargetText.filter(\.isNumber))
    }

    var hasValidCalorieTarget: Bool {
        calorieTarget.map(GoalCalculator.calorieRange.contains) ?? false
    }

    var hasValidMacros: Bool {
        guard macroPreset == .custom else { return true }
        return [proteinText, carbsText, fatText].allSatisfy {
            guard let value = Self.parseNumber($0) else { return false }
            return value.isFinite && (0...999).contains(value)
        }
    }

    var shouldCreateGoal: Bool {
        !skipsGoalSetup && intent.goalIntent != nil
    }

    var goalSummary: String {
        guard shouldCreateGoal, let calorieTarget else { return "Ingen mål satt" }
        return "\(calorieTarget) kcal per dag"
    }

    var macroSummary: String {
        guard shouldCreateGoal else { return "Ingen makromål" }
        if macroPreset == .custom {
            return "Protein \(proteinText) g · Karbohydrater \(carbsText) g · Fett \(fatText) g"
        }
        return macroPreset.label
    }

    private var activeSequence: [Step] {
        if skipsGoalSetup || intent == .loggingOnly {
            return [.privacy, .summary]
        }
        return [.intent, .goalSetup, .personalDetails, .result, .macros, .privacy, .summary]
    }

    private func go(to destination: Step) {
        history.append(step)
        step = destination
        errorMessage = nil
        attemptedResult = false
        attemptedMacros = false
    }

    private func prepareSuggestedTarget() {
        isManualTarget = false
        calorieTargetText = suggestion.map(String.init) ?? ""
    }

    private func makeGoal(userId: UUID) -> Goal? {
        guard let goalIntent = intent.goalIntent,
              let calorieTarget,
              GoalCalculator.calorieRange.contains(calorieTarget) else { return nil }
        let macros = selectedMacros(calories: calorieTarget)
        guard macros.proteinG.isFinite, macros.carbsG.isFinite, macros.fatG.isFinite else { return nil }
        return Goal(
            userId: userId,
            goalType: goalIntent == .lose ? "weight_loss" : goalIntent == .gain ? "gain" : "maintain",
            dailyCalories: calorieTarget,
            proteinTargetG: macros.proteinG,
            carbsTargetG: macros.carbsG,
            fatTargetG: macros.fatG,
            intent: goalIntent,
            pace: pace,
            activityLevel: activity
        )
    }

    private func selectedMacros(calories: Int) -> MacroTargets {
        let custom = MacroTargets(
            proteinG: Float(Self.parseNumber(proteinText) ?? 0),
            carbsG: Float(Self.parseNumber(carbsText) ?? 0),
            fatG: Float(Self.parseNumber(fatText) ?? 0)
        )
        return GoalCalculator.calculateMacros(kcal: calories, preset: macroPreset, custom: custom)
    }

    private func makePersonalDetails() -> PersonalDetails {
        var details = initialDetails
        details.weightKg = Self.parseNumber(weightText)
        details.heightCm = Self.parseNumber(heightText)
        details.birthDate = Int(ageText.filter(\.isNumber)).flatMap(Self.birthDateFromAge)
        details.gender = gender == .ikkeOppgi ? nil : gender
        details.activityLevel = activity
        return details
    }

    private static func parseNumber(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func format(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }

    private static func age(from birthDate: Date?) -> Int? {
        guard let birthDate else { return nil }
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
    }

    private static func birthDateFromAge(_ age: Int) -> Date? {
        Calendar.current.date(byAdding: .year, value: -age, to: Date())
    }
}
