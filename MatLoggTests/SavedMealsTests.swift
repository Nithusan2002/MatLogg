import Foundation
import Testing
@testable import MatLogg

@MainActor
struct SavedMealsTests {
    @Test func savesExistingMealWithExactNutritionSnapshot() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)

        #expect(await fixture.vm.saveFromLogs(
            name: "  Vanlig frokost  ",
            mealType: "frokost",
            logs: [fixture.log],
            userId: fixture.userId
        ))

        let saved = try #require(fixture.repository.savedMeals.first)
        #expect(saved.name == "Vanlig frokost")
        #expect(saved.suggestedMealType == "frokost")
        #expect(saved.items.count == 1)
        #expect(saved.items[0].amountG == fixture.log.amountG)
        #expect(saved.items[0].calories == fixture.log.calories)
        #expect(saved.items[0].nutritionSource == .matvaretabellen)
    }

    @Test func loggingAdjustedMealUsesSnapshotAndUndoDeletesOnlyCreatedLogs() async throws {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let meal = fixture.meal
        fixture.repository.savedMeals = [meal]
        let targetDate = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(await fixture.vm.log(
            meal,
            mealType: "middag",
            date: targetDate,
            amounts: [meal.items[0].id: 100],
            userId: fixture.userId
        ))

        let log = try #require(fixture.repository.savedLogs.first)
        #expect(log.mealType == "middag")
        #expect(log.amountG == 100)
        #expect(log.calories == 400)
        #expect(log.proteinG == 20)
        #expect(Calendar.current.isDate(log.loggedDate, inSameDayAs: targetDate))

        #expect(await fixture.vm.undo())
        #expect(fixture.repository.deletedLogIDs == [log.id])
        #expect(fixture.vm.receipt == nil)
    }

    @Test func missingProductAndInvalidAmountNeverPartiallyLogMeal() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        let missingItem = SavedMealItem(
            productId: UUID(), productName: "Mangler", amountG: 50, calories: 100,
            proteinG: 2, carbsG: 3, fatG: 4, nutritionSource: .user, sortIndex: 1
        )
        var meal = fixture.meal
        meal.items.append(missingItem)

        #expect(await fixture.vm.log(
            meal, mealType: "lunsj", date: Date(),
            amounts: [meal.items[0].id: 0, missingItem.id: 50], userId: fixture.userId
        ) == false)
        #expect(fixture.repository.savedLogs.isEmpty)

        #expect(await fixture.vm.log(
            meal, mealType: "lunsj", date: Date(),
            amounts: [meal.items[0].id: 50, missingItem.id: 50], userId: fixture.userId
        ) == false)
        #expect(fixture.repository.savedLogs.isEmpty)
    }

    @Test func editingTemplateDoesNotChangePastLogs() async throws {
        let fixture = SavedMealsFixture()
        fixture.repository.logs = [fixture.log]
        await fixture.vm.load(userId: fixture.userId)
        let meal = fixture.meal
        fixture.repository.savedMeals = [meal]

        #expect(await fixture.vm.update(
            meal,
            name: "Ny frokost",
            amounts: [meal.items[0].id: 75],
            removedItemIDs: []
        ))

        #expect(fixture.repository.logs.map(\.id) == [fixture.log.id])
        #expect(fixture.repository.savedMeals.last?.name == "Ny frokost")
        #expect(fixture.repository.savedMeals.last?.items[0].amountG == 75)
    }

    @Test func repeatedSaveWhileSuspendedWritesOnlyOnce() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        fixture.repository.suspendSavedMealSave = true

        let firstSave = Task { @MainActor in
            await fixture.vm.saveFromLogs(
                name: "Frokost",
                mealType: "frokost",
                logs: [fixture.log],
                userId: fixture.userId
            )
        }
        await fixture.repository.waitForSuspendedSave()

        #expect(await fixture.vm.saveFromLogs(
            name: "Frokost",
            mealType: "frokost",
            logs: [fixture.log],
            userId: fixture.userId
        ) == false)

        fixture.repository.resumeSavedMealSave()
        #expect(await firstSave.value)
        #expect(fixture.repository.savedMeals.count == 1)
    }

    @Test func resetDuringSaveCannotPublishPreviousAccountsMeal() async {
        let fixture = SavedMealsFixture()
        await fixture.vm.load(userId: fixture.userId)
        fixture.repository.suspendSavedMealSave = true

        let save = Task { @MainActor in
            await fixture.vm.saveFromLogs(
                name: "Frokost",
                mealType: "frokost",
                logs: [fixture.log],
                userId: fixture.userId
            )
        }
        await fixture.repository.waitForSuspendedSave()
        fixture.vm.reset()
        fixture.repository.resumeSavedMealSave()

        #expect(await save.value)
        #expect(fixture.vm.meals.isEmpty)
        #expect(fixture.vm.receipt == nil)
    }
}

@MainActor
private final class SavedMealsFixture {
    let userId = UUID()
    let product = Product(
        name: "Havregryn", source: "matvaretabellen", kind: .genericFood,
        caloriesPer100g: 400, proteinGPer100g: 20, carbsGPer100g: 60, fatGPer100g: 8,
        nutritionSource: .matvaretabellen, verificationStatus: .verified, isVerified: true
    )
    let repository = SavedMealsRepositorySpy()
    lazy var vm = SavedMealsViewModel(savedMealRepository: repository, foodLogRepository: repository)
    lazy var log = FoodLog(
        userId: userId, productId: product.id, mealType: "frokost", amountG: 50,
        loggedDate: Calendar.current.startOfDay(for: Date()), calories: 200,
        proteinG: 10, carbsG: 30, fatG: 4
    )
    lazy var meal = SavedMeal(
        userId: userId,
        name: "Frokost",
        suggestedMealType: "frokost",
        items: [SavedMealItem(
            productId: product.id, productName: product.name, amountG: 50,
            calories: 200, proteinG: 10, carbsG: 30, fatG: 4,
            nutritionSource: .matvaretabellen, sortIndex: 0
        )]
    )

    init() {
        repository.products[product.id] = product
    }
}

@MainActor
private final class SavedMealsRepositorySpy: SavedMealRepository, FoodLogRepository {
    var savedMeals: [SavedMeal] = []
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var savedLogs: [FoodLog] = []
    var deletedLogIDs: [UUID] = []
    var suspendSavedMealSave = false
    private var saveContinuation: CheckedContinuation<Void, Never>?
    private var saveWaiters: [CheckedContinuation<Void, Never>] = []

    func saveSavedMeal(_ meal: SavedMeal) async throws {
        if suspendSavedMealSave {
            saveWaiters.forEach { $0.resume() }
            saveWaiters.removeAll()
            await withCheckedContinuation { saveContinuation = $0 }
        }
        savedMeals.removeAll { $0.id == meal.id }
        savedMeals.append(meal)
    }

    func waitForSuspendedSave() async {
        if saveContinuation != nil { return }
        await withCheckedContinuation { saveWaiters.append($0) }
    }

    func resumeSavedMealSave() {
        suspendSavedMealSave = false
        saveContinuation?.resume()
        saveContinuation = nil
    }
    func deleteSavedMeal(_ id: UUID, userId: UUID) async throws {
        savedMeals.removeAll { $0.id == id && $0.userId == userId }
    }
    func getSavedMeals(userId: UUID) async -> [SavedMeal] { savedMeals.filter { $0.userId == userId } }
    func saveLogs(_ logs: [FoodLog]) async throws { savedLogs.append(contentsOf: logs); self.logs.append(contentsOf: logs) }
    func deleteLogs(_ ids: [UUID]) async throws { deletedLogIDs.append(contentsOf: ids); logs.removeAll { ids.contains($0.id) } }
    func saveLog(_ log: FoodLog) async throws { try await saveLogs([log]) }
    func deleteLog(_ id: UUID) async throws { try await deleteLogs([id]) }
    func getAllLogs(userId: UUID) async -> [FoodLog] { logs.filter { $0.userId == userId } }
    func getProduct(_ id: UUID) -> Product? { products[id] }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary(date: date, totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
}
