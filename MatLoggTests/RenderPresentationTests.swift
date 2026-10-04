import Combine
import Foundation
import Testing
@testable import MatLogg

@MainActor
struct RenderPresentationTests {
    @Test func searchKeepsMealTotalsAndIDsAndUpdatesAfterDataChanges() async throws {
        let repository = RenderLogRepository()
        let owner = UUID(), date = Date()
        let bread = product("Brød"), milk = product("Melk")
        let first = log(owner: owner, product: bread, date: date, time: 20, calories: 120)
        let second = log(owner: owner, product: milk, date: date, time: 10, calories: 80)
        let lunch = log(owner: owner, product: milk, date: date, time: 30, calories: 40, meal: "lunsj")
        repository.logs = [first, lunch, second]
        repository.products = [bread.id: bread, milk.id: milk]
        let logs = LogViewModel(repository: repository)
        let screen = LogScreenViewModel(logs: logs, mealFilter: "frokost")
        await logs.loadSelectedSummary(userId: owner, date: date)
        #expect(screen.presentation.groups.first?.logs.map(\.id) == [second.id, first.id])
        screen.searchText = "BRØD"
        #expect(screen.presentation.groups.first?.logs.map(\.id) == [first.id])
        #expect(screen.presentation.mealLogs.count == 2)
        #expect(screen.presentation.totals.calories == 200)
        screen.mealFilter = "lunsj"
        #expect(screen.presentation.groups.isEmpty)
        #expect(screen.presentation.totals.calories == 40)
        screen.searchText = ""
        #expect(screen.presentation.groups.first?.logs.map(\.id) == [lunch.id])
        repository.logs = [second]
        await logs.loadSelectedSummary(userId: owner, date: date)
        #expect(screen.presentation.mealLogs.isEmpty)
        screen.mealFilter = nil
        #expect(screen.presentation.groups.first?.logs.map(\.id) == [second.id])
        await logs.loadSelectedSummary(userId: nil, date: date)
        #expect(screen.presentation.groups.isEmpty)
        #expect(screen.names.isEmpty)
        #expect(screen.presentation.totals.calories == 0)
    }

    @Test func receiptAndTodayUpdatesDoNotInvalidateLogScreenOrRecalculateGroups() async {
        let repository = RenderLogRepository()
        let logs = LogViewModel(repository: repository)
        let screen = LogScreenViewModel(logs: logs)
        let receipt = LogDeletionReceiptViewModel(logs: logs)
        var screenChanges = 0, receiptChanges = 0, groupChanges = 0
        let screenToken = screen.objectWillChange.sink { screenChanges += 1 }
        let receiptToken = receipt.objectWillChange.sink { receiptChanges += 1 }
        let groupToken = screen.$presentation.dropFirst().sink { _ in groupChanges += 1 }
        logs.dismissDeletionReceipt()
        await logs.loadTodaysSummary(userId: UUID())
        #expect(screenChanges == 0)
        #expect(groupChanges == 0)
        #expect(receiptChanges == 0) // Empty receipt assignments are deduplicated.
        await logs.loadMealProductImages(for: [])
        #expect(groupChanges == 0)
        withExtendedLifetime((screenToken, receiptToken, groupToken)) {}
    }

    @Test func amountTypingDoesNotPublishProductDetailChanges() {
        let model = ProductDetailViewModel(product: product("Brød"), repository: RenderBarcodeRepository())
        var productChanges = 0, amountChanges = 0
        let productToken = model.objectWillChange.sink { productChanges += 1 }
        let amountToken = model.amountModel.objectWillChange.sink { amountChanges += 1 }
        model.amountModel.text = "75"
        #expect(amountChanges > 0)
        #expect(productChanges == 0)
        #expect(model.nutrition(for: model.amountModel.amount).calories == 75)
        withExtendedLifetime((productToken, amountToken)) {}
    }

    @Test func savedMealPresentationKeepsDomainIDsWhenReorderedRemovedAndUpdated() {
        let owner = UUID()
        let first = mealItem("Brød", index: 1), second = mealItem("Melk", index: 0)
        let meal = SavedMeal(userId: owner, name: "Frokost", items: [first, second])
        let model = SavedMealItemsViewModel(meal: meal)
        #expect(model.sortedItems.map(\.id) == [second.id, first.id])
        #expect(model.subtitle == "2 varer · Melk, Brød")
        model.removed.insert(second.id)
        #expect(model.visibleItems.map(\.id) == [first.id])
        var moved = first
        moved.sortIndex = -1
        var updated = meal
        updated.items = [second, moved]
        model.update(updated)
        #expect(model.sortedItems.map(\.id) == [first.id, second.id])
        #expect(model.visibleItems.map(\.id) == [first.id])
        #expect(model.subtitle == "2 varer · Brød, Melk")
        model.removed.remove(second.id)
        #expect(model.visibleItems.map(\.id) == [first.id, second.id])
    }

    @Test func weightLoadingDoesNotInvalidateGoalProjection() async {
        let health = HealthProfileViewModel(repository: RenderHealthRepository())
        let goal = ProgressGoalViewModel(health: health)
        var healthChanges = 0, goalChanges = 0
        let healthToken = health.objectWillChange.sink { healthChanges += 1 }
        let goalToken = goal.objectWillChange.sink { goalChanges += 1 }
        await health.loadWeightEntries(userId: UUID())
        #expect(healthChanges > 0)
        #expect(goalChanges == 0)
        withExtendedLifetime((healthToken, goalToken)) {}
    }

    private func product(_ name: String) -> Product {
        Product(name: name, source: "manual", caloriesPer100g: 100, proteinGPer100g: 10,
                carbsGPer100g: 20, fatGPer100g: 5)
    }
    private func log(owner: UUID, product: Product, date: Date, time: Double,
                     calories: Float, meal: String = "frokost") -> FoodLog {
        FoodLog(userId: owner, productId: product.id, mealType: meal, amountG: 100,
                loggedDate: date, loggedTime: Date(timeIntervalSince1970: time),
                calories: calories, proteinG: 10, carbsG: 20, fatG: 5)
    }
    private func mealItem(_ name: String, index: Int) -> SavedMealItem {
        SavedMealItem(productId: UUID(), productName: name, amountG: 100,
            calories: 100, proteinG: 10, carbsG: 20, fatG: 5, nutritionSource: .user, sortIndex: index)
    }
}

@MainActor
private final class RenderLogRepository: FoodLogRepository {
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    func getAllLogs(userId: UUID) async -> [FoodLog] { logs.filter { $0.userId == userId } }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary.summaries(userId: userId, dates: [date], logs: logs)[0]
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
    func getProduct(_ id: UUID) async -> Product? { products[id] }
    func saveLogs(_ logs: [FoodLog]) async throws {}
    func deleteLogs(_ ids: [UUID]) async throws {}
    func saveLog(_ log: FoodLog) async throws {}
    func deleteLog(_ id: UUID) async throws {}
}

@MainActor
private struct RenderBarcodeRepository: BarcodeLookupRepository {
    func cached(barcode: String, owner: UUID?) async -> Product? { nil }
    func fetch(barcode: String) async throws -> Product { throw BarcodeLookupFailure.unavailable }
    func refresh(_ product: Product, manually: Bool) async throws -> Product? { nil }
}

@MainActor
private struct RenderHealthRepository: HealthProfileRepository {
    func latestGoal(userId: UUID) async -> Goal? { nil }
    func saveGoal(_ goal: Goal) async throws {}
    func saveWeightEntry(_ entry: WeightEntry) async throws {}
    func deleteWeightEntry(_ id: UUID) async throws {}
    func getWeightEntries(userId: UUID) async -> [WeightEntry] { [] }
}
