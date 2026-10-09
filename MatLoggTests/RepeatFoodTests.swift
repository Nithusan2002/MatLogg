import Foundation
import SQLite3
import Testing
@testable import MatLogg

@MainActor
struct RepeatFoodTests {
    @Test func recentFoodsAreBoundedStableAndExcludeFutureAndForeignData() async throws {
        try await withDatabase { store, database, url in
            let owner = UUID(), other = UUID(), now = Date()
            let item = product(), second = product(), foreign = product()
            try store.cacheCatalogProduct(item)
            try store.cacheCatalogProduct(second)
            try store.saveProduct(foreign, ownerUserId: other)
            let time = now.addingTimeInterval(-60)
            let first = log(item, owner: owner, time: time, created: time)
            let latest = log(item, owner: owner, amount: 150, time: time, created: time.addingTimeInterval(1))
            let another = log(second, owner: owner, time: time.addingTimeInterval(-10))
            let future = try #require(Calendar.current.date(byAdding: .day, value: 1, to: now))
            try store.saveLogs([first, latest, another,
                log(item, owner: owner, amount: 900, date: future, time: now),
                log(item, owner: other, amount: 500, time: now),
                log(foreign, owner: owner, time: now)])
            // A legacy private product without an owner is not a shared catalog item.
            try sql("UPDATE products SET ownerUserId = NULL WHERE id = '\(foreign.id.uuidString)';", url: url)
            let count = store.pendingSyncCount()
            let rows = try await database.getRecentFoods(owner: owner, before: now, limit: 6)
            #expect(rows.map(\.id) == [item.id, second.id])
            let times = try await database.getLoggedProductTimes(owner: owner, before: now)
            #expect(Set(times.keys) == [item.id, second.id])
            #expect(abs(try #require(times[item.id]).timeIntervalSince(time)) < 0.000001)
            #expect(rows.first?.log.id == latest.id)
            #expect(rows.first?.log.amountG == 150)
            #expect(try await database.getRecentFoods(owner: owner, before: now, limit: 1).count == 1)
            #expect(try await database.getRecentFoods(owner: owner, before: now, limit: 0).isEmpty)
            #expect(store.pendingSyncCount() == count)
        }
    }

    @Test(arguments: [AmountUnit.grams, .milliliters])
    func repeatsExactAmountWithCurrentNutritionAndUndoTargetsOnlyItsID(unit: AmountUnit) async throws {
        try await withDatabase { store, database, _ in
            let owner = UUID(), item = product(unit: unit)
            try store.cacheCatalogProduct(item)
            let source = log(item, owner: owner, amount: 123.45, time: Date().addingTimeInterval(-60))
            try store.saveLog(source)
            let repository = searchRepository(database)
            let library = try await repository.loadLocalLibrary(owner: owner)
            let food = try #require(library.recentFoods.first)
            #expect(food.canRepeat)
            let date = try #require(Calendar.current.date(byAdding: .day, value: -3, to: Date()))
            let start = Date()
            guard case .logged(let repeatedProduct, let repeated) = try await repository.logAgain(food, owner: owner, mealType: "middag", date: date)
            else { Issue.record("Expected a new log"); return }
            #expect(repeatedProduct.nutritionSource == item.nutritionSource)
            #expect(repeated.id != source.id)
            #expect(repeated.amountG == source.amountG && repeated.resolvedAmountUnit == unit)
            #expect(Calendar.current.isDate(repeated.loggedDate, inSameDayAs: date))
            #expect(repeated.loggedTime >= start)
            #expect(abs(repeated.calories - 246.9) < 0.001) // source snapshot deliberately has 10 kcal
            #expect(store.getAllLogs(userId: owner).first(where: { $0.id == source.id })?.calories == 10)
            let identical = log(item, owner: owner, amount: repeated.amountG, date: date,
                                time: repeated.loggedTime.addingTimeInterval(1), meal: "middag")
            try store.saveLog(identical)
            let vm = LogViewModel(repository: database)
            #expect(!(await vm.undoLatestLog(productId: item.id, mealType: "middag", amountG: repeated.amountG,
                userId: UUID(), date: date, logID: repeated.id)))
            #expect(await vm.undoLatestLog(productId: item.id, mealType: "middag", amountG: repeated.amountG,
                userId: owner, date: date, logID: repeated.id))
            #expect(Set(store.getAllLogs(userId: owner).map(\.id)) == [source.id, identical.id])
            #expect(!(await vm.undoLatestLog(productId: item.id, mealType: "middag", amountG: repeated.amountG,
                userId: owner, date: date, logID: repeated.id)))
            let events = store.fetchPendingEvents(limit: 20)
            #expect(events.filter { $0.entityId == repeated.id.uuidString }.map(\.type) == ["log.upsert", "log.delete"])
            #expect(Set(events.map(\.eventId)).count == events.count)
            #expect(events.allSatisfy { $0.schemaVersion == 1 && $0.ownerUserId == owner })
        }
    }

    @Test func portionSnapshotIsPreservedAndChangedBasisRequiresReview() async throws {
        try await withDatabase { store, database, _ in
            let owner = UUID(), serving = ServingOption(label: "1 beger", grams: 37.5, source: .openFoodFacts, kind: .piece, shortLabel: "beger")
            let item = product(servings: [serving])
            let portion = PortionSelection(servingId: serving.id, label: "beger", count: 2,
                amountPerServing: 37.5, unit: .grams, source: .openFoodFacts, kind: .piece)
            try store.cacheCatalogProduct(item)
            try store.saveLog(log(item, owner: owner, amount: 75, portion: portion, time: Date().addingTimeInterval(-60)))
            let repository = searchRepository(database)
            let food = try #require(try await repository.loadLocalLibrary(owner: owner).recentFoods.first)
            guard case .logged(_, let repeated) = try await repository.logAgain(food, owner: owner, mealType: "lunsj", date: Date())
            else { Issue.record("Expected portion logging"); return }
            #expect(repeated.portionSelection == portion)
            let current = try #require(try await repository.loadLocalLibrary(owner: owner).recentFoods.first)
            let changed = product(id: item.id, servings: [ServingOption(label: "1 beger", grams: 50,
                source: .openFoodFacts, kind: .piece, shortLabel: "beger")])
            try store.cacheCatalogProduct(changed)
            let count = store.pendingSyncCount()
            guard case .review = try await repository.logAgain(current, owner: owner, mealType: "lunsj", date: Date())
            else { Issue.record("Changed portion must require review"); return }
            #expect(store.pendingSyncCount() == count)
            #expect(!RecentFood(product: changed, log: repeated).canRepeat)
            #expect(!RecentFood(product: product(id: item.id, unit: .milliliters), log: repeated).canRepeat)
            #expect(!RecentFood(product: item, log: log(item, owner: owner, amount: 0)).canRepeat)
        }
    }

    @Test func eventFailureRollsBackAndRetryCreatesOneLog() async throws {
        try await withDatabase { store, database, url in
            let owner = UUID(), item = product()
            try store.cacheCatalogProduct(item)
            let source = log(item, owner: owner, time: Date().addingTimeInterval(-60))
            try store.saveLog(source)
            let repository = searchRepository(database)
            let food = try #require(try await repository.loadLocalLibrary(owner: owner).recentFoods.first)
            try sql("CREATE TRIGGER fail_repeat BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT, 'test failure'); END;", url: url)
            await #expect(throws: (any Error).self) {
                try await repository.logAgain(food, owner: owner, mealType: "frokost", date: Date())
            }
            #expect(store.getAllLogs(userId: owner).map(\.id) == [source.id])
            #expect(store.pendingSyncCount() == 1)
            try sql("DROP TRIGGER fail_repeat;", url: url)
            _ = try await repository.logAgain(food, owner: owner, mealType: "frokost", date: Date())
            #expect(store.getAllLogs(userId: owner).count == 2)
            #expect(store.pendingSyncCount() == 2)
            await #expect(throws: (any Error).self) {
                try await repository.logAgain(food, owner: UUID(), mealType: "frokost", date: Date())
            }
        }
    }

    @Test func doubleTapIsBlockedAndContextOrProfileChangeDiscardsPresentation() async throws {
        let repository = RepeatSearchStub(), owner = UUID(), item = product()
        let food = RecentFood(product: item, log: log(item, owner: owner))
        let vm = QuickLogViewModel(repository: repository)
        await vm.load(userId: owner)
        for changeProfile in [false, true] {
            let operation = Task { await vm.logAgain(food, mealType: "middag", date: Date()) }
            for _ in 0..<1_000 {
                if repository.continuation != nil { break }
                await Task.yield()
            }
            #expect(vm.isRepeating)
            #expect(await vm.logAgain(food, mealType: "middag", date: Date()) == nil)
            if changeProfile { await vm.load(userId: UUID()) }
            else { vm.invalidateRepeatPresentation() }
            repository.continuation?.resume(returning: .logged(item, food.log))
            repository.continuation = nil
            #expect(await operation.value == nil)
            #expect(!vm.isRepeating && vm.logError == nil)
        }
        #expect(repository.calls == 2)
    }

    @Test func saveFailureCanRetryAndReviewOpensProductWithoutReceipt() async {
        let repository = RepeatSearchStub(), owner = UUID(), item = product()
        let food = RecentFood(product: item, log: log(item, owner: owner))
        let vm = QuickLogViewModel(repository: repository)
        await vm.load(userId: owner)
        repository.fail = true
        #expect(await vm.logAgain(food, mealType: "lunsj", date: Date()) == nil)
        #expect(vm.logError != nil && !vm.isRepeating)
        repository.fail = false
        repository.review = item
        #expect(await vm.logAgain(food, mealType: "lunsj", date: Date()) == nil)
        #expect(vm.selectedQuickProduct?.id == item.id && vm.logError == nil)
    }

    @Test func searchHistoryIncludesOlderProductsAndReloadsAfterDeletion() async throws {
        try await withDatabase { store, database, _ in
            let owner = UUID(), other = UUID(), old = product(), foreign = product(), future = product()
            for item in [old, foreign, future] { try store.cacheCatalogProduct(item) }
            let now = Date()
            let original = log(old, owner: owner, time: now.addingTimeInterval(-1_000))
            let latest = log(old, owner: owner, time: now.addingTimeInterval(-900))
            try store.saveLogs([original, latest, log(foreign, owner: other, time: now.addingTimeInterval(-10)),
                                log(future, owner: owner, date: now.addingTimeInterval(86_400), time: now)])
            for offset in 1...7 {
                let item = product()
                try store.cacheCatalogProduct(item)
                try store.saveLog(log(item, owner: owner, time: now.addingTimeInterval(Double(-offset))))
            }
            let pending = store.pendingSyncCount()
            let repository = searchRepository(database)
            let library = try await repository.loadLocalLibrary(owner: owner)
            #expect(library.recent.count == 6)
            #expect(!library.recent.contains { $0.id == old.id })
            #expect(library.loggedProductTimes.count == 8)
            #expect(abs(try #require(library.loggedProductTimes[old.id]).timeIntervalSince(latest.loggedTime)) < 0.001)
            #expect(library.loggedProductTimes[foreign.id] == nil && library.loggedProductTimes[future.id] == nil)
            #expect(store.pendingSyncCount() == pending)
            try store.deleteLog(latest.id)
            let reloaded = try await repository.loadLocalLibrary(owner: owner)
            #expect(abs(try #require(reloaded.loggedProductTimes[old.id]).timeIntervalSince(original.loggedTime)) < 0.001)
            try store.deleteLog(original.id)
            #expect(try await repository.loadLocalLibrary(owner: owner).loggedProductTimes[old.id] == nil)
            #expect(try await repository.loadLocalLibrary(owner: other).loggedProductTimes.keys.sorted { $0.uuidString < $1.uuidString } == [foreign.id])
            #expect(try await repository.loadLocalLibrary(owner: nil).loggedProductTimes.isEmpty)
        }
    }

    private func product(id: UUID = UUID(), unit: AmountUnit = .grams, servings: [ServingOption]? = nil) -> Product {
        Product(id: id, name: "Syntetisk testvare", source: "openfoodfacts", caloriesPer100g: 200,
            proteinGPer100g: 10, carbsGPer100g: 20, fatGPer100g: 4, servings: servings,
            nutritionSource: .openFoodFacts, nutritionBasis: unit == .grams ? .per100g : .per100ml)
    }

    private func log(_ product: Product, owner: UUID, amount: Float = 100, portion: PortionSelection? = nil,
                     date: Date = Date(), time: Date = Date(), created: Date = Date(), meal: String = "frokost") -> FoodLog {
        FoodLog(userId: owner, productId: product.id, mealType: meal, amountG: amount,
            amountUnit: product.amountUnit, portionSelection: portion,
            loggedDate: Calendar.current.startOfDay(for: date), loggedTime: time,
            calories: 10, proteinG: 1, carbsG: 2, fatG: 0, createdAt: created)
    }

    private func searchRepository(_ database: DatabaseService) -> DefaultFoodSearchRepository {
        DefaultFoodSearchRepository(products: database, catalog: MatvaretabellenService(),
                                    remote: RepeatRemoteStub(), recentFoods: database)
    }

    private func withDatabase(_ operation: (LocalStore, DatabaseService, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("repeat.sqlite")
        let store = try LocalStore(databaseURL: url)
        try await operation(store, DatabaseService(store: store), url)
    }

    private func sql(_ statement: String, url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw DatabaseServiceError.unavailable }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, statement, nil, nil, nil) == SQLITE_OK else { throw DatabaseServiceError.unavailable }
    }
}

private struct RepeatRemoteStub: ProductNameSearchService {
    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope) async throws -> [Product] { [] }
}

@MainActor
private final class RepeatSearchStub: FoodSearchRepository {
    var continuation: CheckedContinuation<RepeatFoodOutcome, Error>?
    var calls = 0
    var fail = false
    var review: Product?
    func loadLibrary(owner: UUID?) async throws -> FoodSearchLibrary {
        FoodSearchLibrary(products: [], recent: [], favorites: [], suggestions: [])
    }
    func searchRemote(query: String, owner: UUID?, scope: FoodSearchScope) async throws -> [Product] { [] }
    func saveManual(_ product: Product, owner: UUID) async throws {}
    func prepare(_ product: Product, owner: UUID) async throws {}
    func logAgain(_ food: RecentFood, owner: UUID, mealType: String, date: Date) async throws -> RepeatFoodOutcome {
        calls += 1
        if fail { throw DatabaseServiceError.unavailable }
        if let review { return .review(review) }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
}
