import Foundation
import Testing
@testable import MatLogg

struct BusinessRuleTests {
    @Test @MainActor func goldenNutritionSurvivesStorageEditingAndExportForGramsAndMilliliters() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("golden.sqlite")
        let store = try LocalStore(databaseURL: url)
        let database = DatabaseService(store: store)
        let user = User.local(id: UUID())
        let vm = LogViewModel(repository: database)
        // Independent, hand-calculated oracle: 37.5/100 of 240, 8, 20, 4.
        for basis in [NutritionBasis.per100g, .per100ml] {
            let product = Product(name: "QA fasit", caloriesPer100g: 240,
                                  proteinGPer100g: 8, carbsGPer100g: 20,
                                  fatGPer100g: 4, nutritionBasis: basis)
            #expect(await vm.logFood(product: product, amountG: 37.5,
                                     mealType: "frokost", userId: user.id))
            let log = try #require(store.getAllLogs(userId: user.id).first { $0.productId == product.id })
            #expect(log.amountUnit == product.amountUnit)
            #expect(log.calories == 90 && log.proteinG == 3)
            #expect(log.carbsG == 7.5 && log.fatG == 1.5)
            #expect(await vm.updateLog(log, amountG: 75, mealType: "lunsj", userId: user.id))
        }
        let reopened = try LocalStore(databaseURL: url)
        let logs = reopened.getAllLogs(userId: user.id)
        #expect(logs.count == 2)
        for log in logs {
            #expect(log.amountG == 75 && log.calories == 180)
            #expect(log.proteinG == 6 && log.carbsG == 15 && log.fatG == 3)
        }
        let totals = NutritionCalculator.totals(for: logs)
        #expect(totals.calories == 360 && totals.protein == 12)
        #expect(totals.carbs == 30 && totals.fat == 6)
        let exporter = UserDataExportService(logRepository: database, savedMealRepository: database,
            waterRepository: database, healthRepository: database, productRepository: database,
            personalDetailsStore: GoldenPersonalDetailsStore(), profileDataRepository: database)
        let exportURL = try #require(await exporter.export(for: user))
        defer { exporter.removeExport(at: exportURL) }
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: exportURL)) as? [String: Any])
        let exported = try #require(json["logs"] as? [[String: Any]])
        #expect(exported.count == 2)
        for row in exported {
            #expect(row["calories"] as? Double == 180)
            #expect(row["protein_g"] as? Double == 6)
            #expect(row["carbs_g"] as? Double == 15)
            #expect(row["fat_g"] as? Double == 3)
        }
    }

    @Test func validatedNutritionRejectsInvalidAmountsAndNutrition() {
        let valid = NutritionBreakdown(calories: 100, protein: 10, carbs: 20, fat: 5)
        let invalidAmounts: [Float] = [0, -1, .nan, .infinity, -Float.infinity, 10_000.1]

        for amount in invalidAmounts {
            #expect(NutritionCalculator.validatedCalculation(per100: valid, amount: amount) == nil)
        }

        let negativeNutrition = NutritionBreakdown(calories: -1, protein: 10, carbs: 20, fat: 5)
        #expect(NutritionCalculator.validatedCalculation(per100: negativeNutrition, amount: 100) == nil)
        #expect(NutritionCalculator.validatedCalculation(per100: valid, amount: 10_000) != nil)
    }

    @Test @MainActor func loggingInvalidAmountDoesNotWrite() async {
        let repository = BusinessRuleFoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let product = Product(
            name: "Testvare",
            caloriesPer100g: 100,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )

        for amount in [Float(-1), 0, .nan, .infinity, 10_000.1] {
            let succeeded = await viewModel.logFood(
                product: product,
                amountG: amount,
                mealType: "lunsj",
                userId: UUID()
            )
            #expect(!succeeded)
        }

        #expect(repository.savedLogs.isEmpty)
        #expect(viewModel.errorMessage == "Kunne ikke lagre: Sjekk mengden og næringstallene.")
    }

    @Test func scaledSnapshotRejectsInvalidBoundsEvenForZeroNutrition() {
        #expect(NutritionCalculator.scaledSnapshot(
            calories: 0, protein: 0, carbs: 0, fat: 0,
            from: 100, to: -1
        ) == nil)
        #expect(NutritionCalculator.scaledSnapshot(
            calories: 100, protein: 10, carbs: 20, fat: 5,
            from: 0, to: 100
        ) == nil)
        #expect(NutritionCalculator.scaledSnapshot(
            calories: 100, protein: 10, carbs: 20, fat: 5,
            from: 100, to: 10_000.1
        ) == nil)
    }

    @Test func emptyNutritionAndProgressDatasetsReturnZero() {
        let totals = NutritionCalculator.totals(for: [])
        #expect(totals.calories == 0)
        #expect(totals.protein == 0)
        #expect(totals.carbs == 0)
        #expect(totals.fat == 0)

        let metrics = ProgressMetrics(summaries: [])
        #expect(metrics.today == nil)
        #expect(metrics.averageCalories == 0)
    }

    @Test func calorieBalanceCoversRemainingExactOverAndInvalidValues() throws {
        let below = try #require(GoalCalculator.calorieBalance(dailyGoal: 2_000, consumed: 1_500.49))
        #expect(below == CalorieBalance(consumed: 1_500, remaining: 500, over: 0))

        let exact = try #require(GoalCalculator.calorieBalance(dailyGoal: 2_000, consumed: 2_000.49))
        #expect(exact == CalorieBalance(consumed: 2_000, remaining: 0, over: 0))

        let over = try #require(GoalCalculator.calorieBalance(dailyGoal: 2_000, consumed: 2_000.5))
        #expect(over == CalorieBalance(consumed: 2_001, remaining: 0, over: 1))

        #expect(GoalCalculator.calorieBalance(dailyGoal: 2_000, consumed: -1) == nil)
        #expect(GoalCalculator.calorieBalance(dailyGoal: -1, consumed: 0) == nil)
        #expect(GoalCalculator.calorieBalance(dailyGoal: 2_000, consumed: .nan) == nil)
    }

    @Test func displayRoundingUsesOneExplicitFinalRoundingStep() {
        #expect(NutritionDisplay.wholeCalories(0.49) == 0)
        #expect(NutritionDisplay.wholeCalories(0.5) == 1)
        #expect(NutritionDisplay.wholeCalories(1.49) == 1)
        #expect(NutritionDisplay.wholeCalories(1.5) == 2)
        #expect(GoalCalculator.roundedDisplay(1_204) == 1_200)
        #expect(GoalCalculator.roundedDisplay(1_205) == 1_210)
    }

    @Test func groupingHandlesEmptyFiltersSearchAndLimits() {
        #expect(LogSummaryService.groupedLogs(logs: [], productNameLookup: { _ in "" }).isEmpty)

        let early = makeLog(mealType: "frokost", time: Date(timeIntervalSince1970: 10))
        let late = makeLog(mealType: "frokost", time: Date(timeIntervalSince1970: 20))
        let dinner = makeLog(mealType: "middag", time: Date(timeIntervalSince1970: 15))
        let names = [early.productId: "Crème Fraîche", late.productId: "Brød", dinner.productId: "Middag"]

        let filtered = LogSummaryService.groupedLogs(
            logs: [late, dinner, early],
            searchText: "BRØD",
            mealFilter: "frokost",
            productNameLookup: { names[$0, default: ""] }
        )
        #expect(filtered.count == 1)
        #expect(filtered.first?.logs.map(\.id) == [late.id])

        let sorted = LogSummaryService.groupedLogs(logs: [late, early]) { names[$0, default: ""] }
        #expect(sorted.first?.logs.map(\.id) == [early.id, late.id])
        #expect(LogSummaryService.limitedLogs([early, late], limit: 0).isEmpty)
        #expect(LogSummaryService.limitedLogs([early, late], limit: -1).isEmpty)
    }

    @Test func matchingHandlesEmptyCandidatesNormalizationAndEmptyCategories() throws {
        let service = MatchingService()
        let product = Product(
            name: "Testmelk",
            brand: "Merke",
            category: "Meíeri",
            caloriesPer100g: 50,
            proteinGPer100g: 3,
            carbsGPer100g: 5,
            fatGPer100g: 2
        )
        #expect(service.bestMatch(offProduct: product, candidates: []) == nil)

        let normalized = makeCandidate(id: "normalized", category: "MEIERI")
        let different = makeCandidate(id: "different", category: "Bakervarer")
        #expect(service.confidenceScore(offProduct: product, candidate: normalized)
                > service.confidenceScore(offProduct: product, candidate: different))

        let emptyProduct = Product(
            name: "Testmelk",
            brand: "",
            category: "",
            caloriesPer100g: 50,
            proteinGPer100g: 3,
            carbsGPer100g: 5,
            fatGPer100g: 2
        )
        let empty = makeCandidate(id: "empty", brand: "", category: "")
        let missing = makeCandidate(id: "missing", brand: nil, category: nil)
        #expect(service.confidenceScore(offProduct: emptyProduct, candidate: empty)
                == service.confidenceScore(offProduct: emptyProduct, candidate: missing))

        let first = makeCandidate(id: "first", category: "MEIERI")
        let second = makeCandidate(id: "second", category: "MEIERI")
        #expect(try #require(service.bestMatch(offProduct: product, candidates: [first, second])).product.id == "first")
    }

    private func makeLog(mealType: String, time: Date) -> FoodLog {
        FoodLog(
            userId: UUID(), productId: UUID(), mealType: mealType, amountG: 100,
            loggedDate: time, loggedTime: time, calories: 100,
            proteinG: 10, carbsG: 20, fatG: 5
        )
    }

    private func makeCandidate(
        id: String,
        brand: String? = "Merke",
        category: String?
    ) -> MatvaretabellenProduct {
        MatvaretabellenProduct(
            id: id, name: "Testmelk", brand: brand, category: category,
            caloriesPer100g: 50, proteinGPer100g: 3,
            carbsGPer100g: 5, fatGPer100g: 2,
            sugarGPer100g: nil, fiberGPer100g: nil, sodiumMgPer100g: nil
        )
    }
}

@MainActor
private struct GoldenPersonalDetailsStore: PersonalDetailsStore {
    func load(userId: UUID) -> PersonalDetails { .empty }
    func save(_ details: PersonalDetails, userId: UUID) throws { }
}

@MainActor
private final class BusinessRuleFoodLogRepositorySpy: FoodLogRepository {
    private(set) var savedLogs: [FoodLog] = []

    func saveLog(_ log: FoodLog) async throws { savedLogs.append(log) }
    func saveLogs(_ logs: [FoodLog]) async throws { savedLogs.append(contentsOf: logs) }
    func deleteLog(_ id: UUID) async throws {}
    func deleteLogs(_ ids: [UUID]) async throws {}
    func getTodaysSummary(userId: UUID) async -> DailySummary { emptySummary() }
    func getSummary(userId: UUID, date: Date) async -> DailySummary { emptySummary(date: date) }
    func getAllLogs(userId: UUID) async -> [FoodLog] { savedLogs }
    func getProduct(_ id: UUID) -> Product? { nil }
    func getProducts(_ ids: Set<UUID>) async -> [UUID: Product] { [:] }

    private func emptySummary(date: Date = Date()) -> DailySummary {
        DailySummary(
            date: date, totalCalories: 0, totalProtein: 0,
            totalCarbs: 0, totalFat: 0, logs: []
        )
    }
}
