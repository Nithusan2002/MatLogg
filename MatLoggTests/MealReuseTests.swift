import Foundation
import Testing
@testable import MatLogg

@MainActor
struct MealReuseTests {
    @Test func suggestsOnlyYesterdayForOwnerAndEmptyMeals() async throws {
        let f = Fixture()
        f.repo.logs += [f.log(meal: "lunsj"), f.log(meal: "lunsj", date: f.clock.date),
                       f.log(meal: "middag", owner: UUID()),
                       f.log(meal: "snacks", date: f.clock.date.addingTimeInterval(-3 * 86_400))]
        await f.load()
        #expect(f.vm.suggestions.map(\.mealType) == ["frokost"])
        #expect(f.repo.saveCalls == 0)
        f.vm.dismissSuggestion(mealType: "frokost")
        await f.load()
        #expect(f.vm.suggestions.isEmpty)
    }

    @Test func missingProductSuppressesWholeMeal() async {
        let f = Fixture()
        f.repo.logs.append(f.log(productId: UUID()))
        await f.load()
        #expect(f.vm.suggestions.isEmpty)
    }

    @Test func unchangedMealPreservesSnapshotAndUndoDeletesOnlyNewIDs() async throws {
        let f = Fixture()
        let original = try #require(f.repo.logs.first)
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        #expect(await f.vm.log(suggestion))
        let copy = try #require(f.repo.saved.first)
        #expect(copy.id != original.id)
        #expect(copy.productId == original.productId)
        #expect(copy.amountG == original.amountG)
        #expect(copy.calories == original.calories)
        #expect(copy.proteinG == original.proteinG)
        #expect(copy.carbsG == original.carbsG)
        #expect(copy.fatG == original.fatG)
        #expect(copy.loggedDate == f.calendar.startOfDay(for: f.clock.date))
        #expect(f.vm.receipt?.logIDs == [copy.id])
        #expect(f.vm.receipt?.title == "Frokost")
        let otherLog = f.log(meal: "middag", date: f.clock.date)
        f.repo.logs.append(otherLog)
        #expect(await f.vm.undo())
        #expect(f.repo.deleted == [copy.id])
        #expect(Set(f.repo.logs.map(\.id)) == [original.id, otherLog.id])
        #expect(f.vm.receipt == nil)
        await f.load()
        #expect(f.vm.suggestions.isEmpty)
    }

    @Test func adjustmentUsesHistoricalNutritionAndCommaInput() async throws {
        let f = Fixture()
        let removable = f.log()
        f.repo.logs.append(removable)
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.vm.edit(suggestion)
        let kept = try #require(suggestion.items.first { $0.id != removable.id })
        f.vm.setAmount(itemId: kept.id, text: "30,25")
        f.vm.removeItem(id: removable.id)
        #expect(f.vm.isDraftValid)
        #expect(await f.vm.logDraft())
        let saved = try #require(f.repo.saved.first)
        #expect(f.repo.saved.count == 1)
        #expect(saved.amountG == 30.25)
        #expect(abs(saved.proteinG - kept.original.proteinG * (30.25 / kept.original.amountG)) < 0.0001)
        // Product values deliberately differ from the stored snapshot.
        #expect(saved.calories != f.product.calculateNutrition(forGrams: 30.25).calories)
    }

    @Test func invalidAmountsAndEmptyDraftCannotBeSaved() async throws {
        let f = Fixture()
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        for value in ["", "0", "-1", "nan", "inf", "10001", "abc"] {
            f.vm.edit(suggestion)
            f.vm.setAmount(itemId: suggestion.items[0].id, text: value)
            #expect(!f.vm.isDraftValid)
            #expect(await f.vm.logDraft() == false)
        }
        f.vm.removeItem(id: suggestion.items[0].id)
        #expect(!f.vm.isDraftValid)
        #expect(await f.vm.logDraft() == false)
        #expect(f.repo.saveCalls == 0)
    }

    @Test func failedSaveRetainsDraftAndRetrySavesOnce() async throws {
        let f = Fixture()
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.vm.edit(suggestion)
        f.vm.setAmount(itemId: suggestion.items[0].id, text: "75,5")
        f.repo.failSave = true
        #expect(await f.vm.logDraft() == false)
        #expect(f.vm.draft?.items.first?.amountText == "75,5")
        #expect(f.vm.errorMessage != nil)
        #expect(f.vm.receipt == nil)
        #expect(f.repo.saved.isEmpty)
        f.repo.failSave = false
        #expect(await f.vm.logDraft())
        #expect(f.repo.saved.count == 1)
        #expect(f.vm.draft == nil)
    }

    @Test func doubleTapWhileSavingDoesNotDuplicateMeal() async throws {
        let f = Fixture()
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.repo.suspendSave = true
        let first = Task { await f.vm.log(suggestion) }
        while f.repo.saveContinuation == nil { await Task.yield() }
        #expect(f.vm.isSaving)
        #expect(await f.vm.log(suggestion) == false)
        f.repo.saveContinuation?.resume()
        #expect(await first.value)
        #expect(f.repo.saveCalls == 1)
        #expect(await f.vm.log(suggestion) == false)
        #expect(f.repo.saved.count == 1)
    }

    @Test func newlyLoggedMealIsRecheckedBeforeSave() async throws {
        let f = Fixture()
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.repo.logs.append(f.log(date: f.clock.date))
        #expect(await f.vm.log(suggestion) == false)
        #expect(f.repo.saveCalls == 0)
    }

    @Test func failedUndoRetainsReceiptForRetry() async throws {
        let f = Fixture()
        await f.load()
        #expect(await f.vm.log(try #require(f.vm.suggestions.first)))
        let ids = f.vm.receipt?.logIDs
        f.repo.failDelete = true
        #expect(await f.vm.undo() == false)
        #expect(f.vm.receipt?.logIDs == ids)
        f.repo.failDelete = false
        #expect(await f.vm.undo())
        #expect(f.repo.deleted == ids)
    }

    @Test func midnightInvalidatesSuggestionAndReceipt() async throws {
        let f = Fixture()
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.clock.date = f.calendar.date(byAdding: .day, value: 1, to: f.clock.date)!
        #expect(await f.vm.log(suggestion) == false)
        #expect(f.repo.saveCalls == 0)
        f.clock.date = f.calendar.date(byAdding: .day, value: -1, to: f.clock.date)!
        #expect(await f.vm.log(suggestion))
        f.clock.date = f.calendar.date(byAdding: .day, value: 1, to: f.clock.date)!
        #expect(await f.vm.undo() == false)
        #expect(f.repo.deleted.isEmpty)
        await f.load()
        #expect(f.vm.receipt == nil)
    }

    @Test func logoutClearsDraftAndReceiptBeforeNextAccountLoads() async throws {
        let f = Fixture()
        f.repo.logs.append(f.log(meal: "lunsj"))
        await f.load()
        let breakfast = try #require(f.vm.suggestions.first { $0.mealType == "frokost" })
        #expect(await f.vm.log(breakfast))
        f.vm.edit(try #require(f.vm.suggestions.first))
        #expect(f.vm.draft != nil)
        f.vm.reset()
        #expect(f.vm.draft == nil)
        #expect(f.vm.receipt == nil)
        #expect(f.vm.suggestions.isEmpty)
        #expect(await f.vm.undo() == false)
        #expect(await f.vm.log(breakfast) == false)
        await f.vm.load(userId: UUID())
        #expect(f.vm.suggestions.isEmpty)
        #expect(f.repo.deleted.isEmpty)
    }

    @Test func lateReadCannotRestorePreviousAccountAfterReset() async {
        let f = Fixture()
        f.repo.suspendRead = true
        let load = Task { await f.load() }
        while f.repo.readContinuation == nil { await Task.yield() }
        f.vm.reset()
        f.repo.readContinuation?.resume()
        await load.value
        #expect(f.vm.suggestions.isEmpty)
        #expect(f.vm.draft == nil)
    }

    @Test func scaledCaloriesOutsideStorageRangeAreRejected() async throws {
        let f = Fixture()
        f.repo.logs = [f.log(amount: 0.000001)]
        await f.load()
        let suggestion = try #require(f.vm.suggestions.first)
        f.vm.edit(suggestion)
        f.vm.setAmount(itemId: suggestion.items[0].id, text: "10000")
        #expect(await f.vm.logDraft() == false)
        #expect(f.repo.saved.isEmpty)
        #expect(f.vm.errorMessage != nil)
    }
}

@MainActor
private final class Fixture {
    let userId = UUID()
    let repo = MealReuseRepositorySpy()
    let clock = TestClock()
    let calendar: Calendar
    let product = Product(name: "Syntetisk testvare", caloriesPer100g: 900,
                          proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 1)
    lazy var vm = MealReuseViewModel(repository: repo, calendar: calendar, now: { [clock] in clock.date })

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Oslo")!
        self.calendar = calendar
        repo.products[product.id] = product
        repo.logs = [log()]
    }

    func load() async { await vm.load(userId: userId) }

    func log(meal: String = "frokost", date: Date? = nil, owner: UUID? = nil,
             productId: UUID? = nil, amount: Float = 60.5) -> FoodLog {
        let date = date ?? calendar.date(byAdding: .day, value: -1, to: clock.date)!
        return FoodLog(userId: owner ?? userId, productId: productId ?? product.id,
                       mealType: meal, amountG: amount, loggedDate: calendar.startOfDay(for: date),
                       loggedTime: date, calories: 217, proteinG: 7.25, carbsG: 34.75, fatG: 3.625)
    }
}

@MainActor
private final class TestClock { var date = Date(timeIntervalSince1970: 1_790_000_000) }

@MainActor
private final class MealReuseRepositorySpy: FoodLogRepository {
    enum Failure: Error { case injected }
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var saved: [FoodLog] = []
    var deleted: [UUID] = []
    var saveCalls = 0
    var failSave = false
    var failDelete = false
    var suspendSave = false
    var suspendRead = false
    var saveContinuation: CheckedContinuation<Void, Never>?
    var readContinuation: CheckedContinuation<Void, Never>?

    func saveLogs(_ logs: [FoodLog]) async throws {
        saveCalls += 1
        if suspendSave { await withCheckedContinuation { saveContinuation = $0 } }
        if failSave { throw Failure.injected }
        saved.append(contentsOf: logs)
        self.logs.append(contentsOf: logs)
    }
    func deleteLogs(_ ids: [UUID]) async throws {
        if failDelete { throw Failure.injected }
        deleted.append(contentsOf: ids)
        logs.removeAll { ids.contains($0.id) }
    }
    func saveLog(_ log: FoodLog) async throws { try await saveLogs([log]) }
    func deleteLog(_ id: UUID) async throws { try await deleteLogs([id]) }
    func getAllLogs(userId: UUID) async -> [FoodLog] {
        if suspendRead { await withCheckedContinuation { readContinuation = $0 } }
        // Deliberately unfiltered to verify the feature's ownership guard.
        return logs
    }
    func getProduct(_ id: UUID) -> Product? { products[id] }
    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        DailySummary(date: date, totalCalories: 0, totalProtein: 0, totalCarbs: 0, totalFat: 0, logs: [])
    }
    func getTodaysSummary(userId: UUID) async -> DailySummary { await getSummary(userId: userId, date: Date()) }
}
