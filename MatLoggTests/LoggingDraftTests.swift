import Foundation
import Testing
import SQLite3
import UIKit
@testable import MatLogg

struct LoggingDraftTests {
    private func url() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("draft-\(UUID()).sqlite") }
    private func product(_ draft: FoodLoggingDraft) -> Product {
        Product(id: draft.productId, name: "Testmat", caloriesPer100g: 100,
                proteinGPer100g: 10, carbsGPer100g: 10, fatGPer100g: 2)
    }
    private func log(_ draft: FoodLoggingDraft) -> FoodLog {
        FoodLog(id: draft.logId, userId: draft.userId, productId: draft.productId, mealType: draft.mealType,
                amountG: 50, loggedDate: draft.date, calories: 50, proteinG: 5, carbsG: 5, fatG: 1)
    }

    @Test func reopenPreservesIncompleteInputImageDateAndOwner() throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        var draft = FoodLoggingDraft(userId: UUID(), barcode: "123", mealType: "lunsj", date: Date(timeIntervalSince1970: 1000))
        draft.input.name = "Uferdig"
        draft.input.calories = "12,"
        draft.input.protein = "ugyldig"
        draft.input.basis = .serving
        draft.input.servingAmount = "40,5"
        draft.input.imageData = Data([1, 2, 3])
        try store.createLoggingDraft(draft)
        let reopened = try LocalStore(databaseURL: path)
        let restored = try #require(try reopened.loadLoggingDraft(owner: draft.userId))
        #expect(restored.id == draft.id)
        #expect(restored.input.protein == "ugyldig")
        #expect(restored.input.calories == "12,")
        #expect(restored.input.servingAmount == "40,5")
        #expect(restored.input.basis == .serving)
        #expect(restored.input.imageData == Data([1, 2, 3]))
        #expect(restored.date == draft.date)
        #expect(try reopened.loadLoggingDraft(owner: UUID()) == nil)
        #expect(store.localDataSummary(ownerId: draft.userId).hasData)
        #expect(store.pendingSyncCount() == 0)
        #expect(try store.exportProfileRecords(ownerId: draft.userId)["food_logging_drafts"]?.count == 1)
    }

    @Test func staleWritesCannotOverwriteOrResurrectAndSecondDraftIsRejected() throws {
        let store = try LocalStore(databaseURL: url())
        var draft = FoodLoggingDraft(userId: UUID(), mealType: "middag", date: Date())
        try store.createLoggingDraft(draft)
        #expect(throws: (any Error).self) {
            try store.createLoggingDraft(FoodLoggingDraft(userId: draft.userId, mealType: "lunsj", date: Date()))
        }
        let old = draft
        draft.revision += 1; draft.input.name = "Ny"
        try store.updateLoggingDraft(draft)
        #expect(throws: (any Error).self) { try store.updateLoggingDraft(old) }
        try store.discardLoggingDraft(id: draft.id, owner: UUID())
        #expect(try store.loadLoggingDraft(owner: draft.userId) != nil)
        try store.discardLoggingDraft(id: draft.id, owner: draft.userId)
        #expect(throws: (any Error).self) { try store.updateLoggingDraft(draft) }
        #expect(try store.loadLoggingDraft(owner: draft.userId) == nil)
    }

    @Test func transitionAndCompletionAreAtomicAndIdempotentAcrossReopen() throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        var draft = FoodLoggingDraft(userId: UUID(), mealType: "lunsj", date: Date())
        try store.createLoggingDraft(draft)
        let food = product(draft)
        draft.revision += 1; draft.step = .amount; draft.product = food
        draft.amountText = "50,0"
        try store.advanceLoggingDraft(draft, product: food)
        try store.advanceLoggingDraft(draft, product: food)
        #expect(store.pendingSyncCount() == 1)
        let reopened = try LocalStore(databaseURL: path)
        #expect(try reopened.loadLoggingDraft(owner: draft.userId)?.amountText == "50,0")
        #expect(reopened.getProduct(food.id)?.name == "Testmat")
        let entry = log(draft)
        try reopened.completeLoggingDraft(draft, log: entry)
        try reopened.completeLoggingDraft(draft, log: entry)
        #expect(reopened.getAllLogs(userId: draft.userId).count == 1)
        #expect(reopened.pendingSyncCount() == 2)
        #expect(try reopened.loadLoggingDraft(owner: draft.userId) == nil)
        #expect(throws: (any Error).self) { try reopened.updateLoggingDraft(draft) }
    }

    @Test func foreignProductIDCannotBeOverwrittenByDraft() throws {
        let store = try LocalStore(databaseURL: url())
        var draft = FoodLoggingDraft(userId: UUID(), mealType: "lunsj", date: Date())
        let food = product(draft)
        try store.saveProduct(food, ownerUserId: UUID())
        try store.createLoggingDraft(draft)
        draft.revision += 1; draft.step = .amount; draft.product = food
        #expect(throws: (any Error).self) { try store.advanceLoggingDraft(draft, product: food) }
        #expect(try store.loadLoggingDraft(owner: draft.userId)?.step == .product)
        #expect(store.pendingSyncCount() == 1)
    }

    @Test func failedDomainTransactionsRetainDraftWithoutPartialWrites() throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        var draft = FoodLoggingDraft(userId: UUID(), mealType: "lunsj", date: Date())
        try store.createLoggingDraft(draft)
        var db: OpaquePointer?
        try #require(sqlite3_open(path.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "CREATE TRIGGER fail_event BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT, 'test'); END;", nil, nil, nil) == SQLITE_OK)
        draft.revision += 1; draft.step = .amount; draft.product = product(draft)
        #expect(throws: (any Error).self) { try store.advanceLoggingDraft(draft, product: product(draft)) }
        #expect(try store.loadLoggingDraft(owner: draft.userId)?.step == .product)
        #expect(store.getProduct(draft.productId) == nil)
        try #require(sqlite3_exec(db, "DROP TRIGGER fail_event;", nil, nil, nil) == SQLITE_OK)
        try store.advanceLoggingDraft(draft, product: product(draft))
        try #require(sqlite3_exec(db, "CREATE TRIGGER fail_event BEFORE INSERT ON sync_queue BEGIN SELECT RAISE(ABORT, 'test'); END;", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try store.completeLoggingDraft(draft, log: log(draft)) }
        #expect(store.getAllLogs(userId: draft.userId).isEmpty)
        #expect(try store.loadLoggingDraft(owner: draft.userId)?.step == .amount)
        #expect(store.pendingSyncCount() == 1)
    }

    @Test func corruptAndUnknownDraftsFailWithoutOverwriting() throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        let draft = FoodLoggingDraft(userId: UUID(), mealType: "lunsj", date: Date())
        try store.createLoggingDraft(draft)
        var db: OpaquePointer?
        try #require(sqlite3_open(path.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var unknown = draft; unknown.schemaVersion = 99
        let json = try JSONEncoder().encode(unknown).map { String(format: "%02x", $0) }.joined()
        try #require(sqlite3_exec(db, "UPDATE food_logging_drafts SET json = X'\(json)';", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try store.loadLoggingDraft(owner: draft.userId) }
        #expect(throws: (any Error).self) { try store.updateLoggingDraft(draft) }
        try #require(sqlite3_exec(db, "UPDATE food_logging_drafts SET json = X'7B';", nil, nil, nil) == SQLITE_OK)
        #expect(throws: (any Error).self) { try store.loadLoggingDraft(owner: draft.userId) }
        #expect(throws: (any Error).self) { try store.createLoggingDraft(draft) }
    }

    @Test func deletionAndProfileClaimIncludeDrafts() throws {
        let store = try LocalStore(databaseURL: url())
        let local = UUID(), account = UUID(), other = UUID()
        try store.createLoggingDraft(FoodLoggingDraft(userId: local, mealType: "lunsj", date: Date()))
        try store.createLoggingDraft(FoodLoggingDraft(userId: other, mealType: "middag", date: Date()))
        try store.claimLocalData(from: local, to: account)
        #expect(try store.loadLoggingDraft(owner: local) == nil)
        #expect(try store.loadLoggingDraft(owner: account)?.userId == account)
        try store.deleteLocalData(ownerId: account)
        #expect(try store.loadLoggingDraft(owner: account) == nil)
        #expect(try store.loadLoggingDraft(owner: other) != nil)
        try store.resetAllData()
        #expect(try store.loadLoggingDraft(owner: other) == nil)
    }

    @MainActor @Test func autosaveFailureRetainsInputAndDiscardCancelsPendingSave() async throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        let model = FoodLoggingDraftViewModel(repository: DatabaseService(store: store))
        let owner = UUID()
        await model.load(owner: owner)
        #expect(await model.start(barcode: nil, mealType: "lunsj", date: Date()))
        let manual = try #require(model.manualModel)
        var db: OpaquePointer?
        try #require(sqlite3_open(path.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, "CREATE TRIGGER fail_draft BEFORE UPDATE ON food_logging_drafts BEGIN SELECT RAISE(ABORT, 'test'); END;", nil, nil, nil) == SQLITE_OK)
        manual.name = "Behold denne teksten"
        #expect(await model.flush() == false)
        #expect(manual.name == "Behold denne teksten")
        #expect(model.errorMessage != nil)
        try #require(sqlite3_exec(db, "DROP TRIGGER fail_draft;", nil, nil, nil) == SQLITE_OK)
        #expect(await model.flush())
        manual.calories = "12,"
        #expect(await model.discard())
        try await Task.sleep(for: .milliseconds(400))
        #expect(try store.loadLoggingDraft(owner: owner) == nil)
        await model.load(owner: UUID())
        manual.name = "Gammel profil"
        #expect(model.draft == nil)
        #expect(model.errorMessage == nil)
    }

    @MainActor @Test func viewModelRestoresRawInputAndCompletesStableLog() async throws {
        let store = try LocalStore(databaseURL: url())
        let repository = DatabaseService(store: store)
        let owner = UUID()
        let first = FoodLoggingDraftViewModel(repository: repository)
        await first.load(owner: owner)
        #expect(await first.start(barcode: nil, mealType: "middag", date: Date(timeIntervalSince1970: 1000)))
        let manual = try #require(first.manualModel)
        manual.name = "Mat"; manual.calories = "100"; manual.protein = "10"
        manual.carbs = "10"; manual.fat = "2"
        #expect(await first.flush())
        let second = FoodLoggingDraftViewModel(repository: repository)
        await second.load(owner: owner)
        #expect(second.manualModel?.name == "Mat")
        #expect(await second.manualModel?.save() != nil)
        let amount = try #require(second.amountModel)
        amount.text = "50,5"
        #expect(await second.flush())
        let third = FoodLoggingDraftViewModel(repository: repository)
        await third.load(owner: owner)
        #expect(third.amountModel?.text == "50,5")
        let receipt = try #require(await third.complete())
        #expect(receipt.ownerID == owner)
        #expect(receipt.loggedDate == Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1000)))
        #expect(store.getAllLogs(userId: owner).count == 1)
        await third.load(owner: UUID())
        #expect(third.draft == nil)
    }
    @MainActor @Test func immediateDiskReadExposesDebounceWindowThenAutosaveCommits() async throws {
        let path = url()
        let store = try LocalStore(databaseURL: path)
        let owner = UUID()
        let model = FoodLoggingDraftViewModel(repository: DatabaseService(store: store))
        await model.load(owner: owner)
        #expect(await model.start(barcode: nil, mealType: "lunsj", date: Date()))
        let manual = try #require(model.manualModel)
        manual.name = "Siste tastetrykk"
        // A process death here can only recover the previously committed snapshot.
        #expect(try LocalStore(databaseURL: path).loadLoggingDraft(owner: owner)?.input.name == "")
        try await Task.sleep(for: .seconds(1))
        #expect(try LocalStore(databaseURL: path).loadLoggingDraft(owner: owner)?.input.name == "Siste tastetrykk")
        #expect(await model.discard())
    }

    @MainActor @Test func preparedImageAndTextSurviveRealDatabaseReopen() async throws {
        let path = url()
        let owner = UUID()
        let model = FoodLoggingDraftViewModel(repository: DatabaseService(store: try LocalStore(databaseURL: path)))
        await model.load(owner: owner)
        #expect(await model.start(barcode: nil, mealType: "lunsj", date: Date()))
        let manual = try #require(model.manualModel)
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
        manual.name = "Bildeutkast"
        await manual.selectImage(image)
        #expect(manual.imageError == nil)
        let imported = try #require(manual.input.imageData)
        #expect(await model.flush())
        let restored = FoodLoggingDraftViewModel(repository: DatabaseService(store: try LocalStore(databaseURL: path)))
        await restored.load(owner: owner)
        #expect(restored.manualModel?.name == "Bildeutkast")
        #expect(restored.manualModel?.input.imageData == imported)
        #expect(restored.manualModel?.productImage != nil)
        await restored.manualModel?.selectImage(nil)
        #expect(await restored.flush())
        #expect(try LocalStore(databaseURL: path).loadLoggingDraft(owner: owner)?.input.imageData == nil)
        #expect(await restored.discard())
    }

}
