//
//  MatLoggTests.swift
//  MatLoggTests
//
//  Created by Nithusan Krishnasamymudali on 21/01/2026.
//

import Testing
import Foundation
import SQLite3
@testable import MatLogg

struct MatLoggTests {
    private static let e2eProductId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private static let e2eEventId = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

    @Test func appTabsHaveStableFiveTabOrder() {
        #expect(AppTab.allCases == [.home, .search, .add, .progress, .profile])
    }

    @Test func progressMetricsCalculateWeeklyAverageAndTodaysMeals() {
        let userId = UUID()
        let productId = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = Date(timeIntervalSince1970: 1_700_000_000)
        let secondDay = calendar.date(byAdding: .day, value: 1, to: firstDay)!
        let breakfast = FoodLog(
            userId: userId,
            productId: productId,
            mealType: "frokost",
            amountG: 100,
            loggedDate: secondDay,
            loggedTime: secondDay,
            calories: 400,
            proteinG: 20,
            carbsG: 30,
            fatG: 10
        )
        let metrics = ProgressMetrics(summaries: [
            DailySummary(date: firstDay, totalCalories: 1_600, totalProtein: 80, totalCarbs: 180, totalFat: 50, logs: []),
            DailySummary(date: secondDay, totalCalories: 2_000, totalProtein: 100, totalCarbs: 220, totalFat: 60, logs: [breakfast])
        ])

        #expect(metrics.averageCalories == 1_800)
        #expect(metrics.today?.date == secondDay)
    }

    @Test @MainActor func mealPresentationContainsEverySupportedMealOnce() {
        #expect(MealPresentation.all.map(\.key) == ["frokost", "lunsj", "middag", "snacks"])
        #expect(Set(MealPresentation.all.map(\.id)).count == 4)
        #expect(MealPresentation.all.last?.title == "Kveldsmat")
        #expect(LogSummaryService.title(for: "snacks") == "Kveldsmat")
    }

    @Test func mealGroupingKeepsCanonicalStorageOrder() {
        let userId = UUID()
        let productId = UUID()
        let now = Date()
        let logs = ["snacks", "frokost", "middag"].map { meal in
            FoodLog(
                userId: userId,
                productId: productId,
                mealType: meal,
                amountG: 100,
                loggedDate: now,
                loggedTime: now,
                calories: 100,
                proteinG: 10,
                carbsG: 10,
                fatG: 10
            )
        }

        let grouped = LogSummaryService.groupedLogs(logs: logs) { _ in "Test" }
        #expect(grouped.map(\.mealType) == ["frokost", "middag", "snacks"])
    }

    @Test func goalCalculatorDoesNotGuessWhenDataIsMissing() async throws {
        let input = GoalCalculationInput(
            weightKg: nil,
            heightCm: nil,
            ageYears: nil,
            gender: nil,
            activity: .moderat,
            intent: .maintain,
            pace: .calm
        )
        let result = GoalCalculator.calculateSuggestion(input: input)
        #expect(result == nil)
    }
    
    @Test func goalCalculatorAdjustsForIntentAndPace() async throws {
        let input = GoalCalculationInput(
            weightKg: 80,
            heightCm: 180,
            ageYears: 30,
            gender: .mann,
            activity: .moderat,
            intent: .lose,
            pace: .standard
        )
        let result = try #require(GoalCalculator.calculateSuggestion(input: input))
        #expect(result.suggestedCalories < result.baselineCalories)
    }
    
    @Test func goalCalculatorClampsExtremes() async throws {
        let input = GoalCalculationInput(
            weightKg: 30,
            heightCm: 140,
            ageYears: 80,
            gender: .kvinne,
            activity: .lav,
            intent: .lose,
            pace: .fast
        )
        let result = try #require(GoalCalculator.calculateSuggestion(input: input))
        #expect(result.suggestedCalories >= 1200)
    }

    @Test func goalCalculatorRejectsUnsupportedAgeAndFormulaBasis() {
        let minor = GoalCalculationInput(weightKg: 60, heightCm: 170, ageYears: 17,
                                         gender: .kvinne, activity: .moderat,
                                         intent: .maintain, pace: .calm)
        let unspecified = GoalCalculationInput(weightKg: 75, heightCm: 180, ageYears: 30,
                                               gender: .annet, activity: .moderat,
                                               intent: .maintain, pace: .calm)
        #expect(GoalCalculator.calculateSuggestion(input: minor) == nil)
        #expect(GoalCalculator.calculateSuggestion(input: unspecified) == nil)
    }

    @Test func goalCalculatorRejectsImplausibleAdultMeasurements() {
        let implausibleWeight = GoalCalculationInput(weightKg: 1, heightCm: 170, ageYears: 30,
                                                     gender: .kvinne, activity: .moderat,
                                                     intent: .maintain, pace: .calm)
        let implausibleHeight = GoalCalculationInput(weightKg: 75, heightCm: 20, ageYears: 30,
                                                     gender: .mann, activity: .moderat,
                                                     intent: .maintain, pace: .calm)
        #expect(GoalCalculator.calculateSuggestion(input: implausibleWeight) == nil)
        #expect(GoalCalculator.calculateSuggestion(input: implausibleHeight) == nil)
    }

    @Test func macroPresetsUseAdultNordicReferenceRanges() {
        let balanced = GoalCalculator.calculateMacros(kcal: 2000, preset: .balanced)
        #expect(balanced.proteinG == 75)
        #expect(balanced.carbsG == 250)
        #expect(abs(balanced.fatG - 77.77778) < 0.001)

        let protein = GoalCalculator.calculateMacros(kcal: 2000, preset: .proteinFocus)
        #expect(protein.proteinG == 100)
        #expect(protein.carbsG == 225)

        let carbs = GoalCalculator.calculateMacros(kcal: 2000, preset: .carbFocus)
        #expect(carbs.proteinG == 75)
        #expect(carbs.carbsG == 275)
    }
    
    @Test func backoffRespectsBounds() async throws {
        let first = Backoff.nextDelay(attempt: 1)
        let later = Backoff.nextDelay(attempt: 6)
        #expect(first >= 10)
        #expect(later <= 6 * 60 * 60)
        #expect(later >= first)
    }
    
    @Test func inFlightResetsToPending() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 150,
            carbsTargetG: 250,
            fatTargetG: 65
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        let target = pending.first(where: { $0.entityId == goal.id.uuidString })
        #expect(target != nil)
        guard let event = target else { return }
        #expect(event.type == "goal.set")
        #expect(event.schemaVersion == 1)
        let payload = try JSONSerialization.jsonObject(with: event.payload) as? [String: Any]
        #expect(payload?["kcalTarget"] as? Int == 2000)
        #expect(payload?["proteinTarget"] as? Double == 150)
        await db.markEventsInFlight([event.eventId])
        await db.resetInFlightEvents()
        let pendingAfterReset = await db.fetchPendingEvents(limit: 50)
        #expect(pendingAfterReset.contains(where: { $0.eventId == event.eventId }))
    }

    @Test func restartRecoversInFlightEventWithStableId() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggSyncRestart-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let databaseURL = directory.appendingPathComponent("restart.sqlite")
        defer { try? FileManager.default.removeItem(at: directory) }

        var store: LocalStore? = try LocalStore(databaseURL: databaseURL)
        let goal = Goal(
            userId: UUID(),
            goalType: "maintain",
            dailyCalories: 2200,
            proteinTargetG: 150,
            carbsTargetG: 275,
            fatTargetG: 70
        )
        try store?.saveGoal(goal)

        let created = try #require(store?.fetchPendingEvents(limit: 10).first)
        store?.markEventsInFlight([created.eventId])
        #expect(store?.fetchPendingEvents(limit: 10).isEmpty == true)

        store = nil
        let reopenedStore = try LocalStore(databaseURL: databaseURL)
        let recovered = try #require(
            reopenedStore.fetchPendingEvents(limit: 10)
                .first(where: { $0.entityId == goal.id.uuidString })
        )

        #expect(recovered.eventId == created.eventId)
        #expect(recovered.status == .pending)
        #expect(recovered.attemptCount == 1)
        #expect(recovered.type == "goal.set")
        #expect(recovered.payload == created.payload)
    }

    @Test @MainActor func localProfileClaimMovesDomainAndQueueOwnershipAtomically() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggProfileClaim-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("claim.sqlite"))
        let localId = UUID()
        let accountId = UUID()
        let goal = Goal(
            userId: localId,
            goalType: "maintain",
            dailyCalories: 2_000,
            proteinTargetG: 100,
            carbsTargetG: 250,
            fatTargetG: 70
        )
        try store.saveGoal(goal)
        let originalEvent = try #require(store.fetchPendingEvents(ownerUserId: localId, limit: 10).first)

        try store.claimLocalData(from: localId, to: accountId)

        #expect(store.localDataSummary(ownerId: localId) == .empty)
        #expect(store.localDataSummary(ownerId: accountId).goals == 1)
        #expect(store.getLatestGoal(userId: localId) == nil)
        #expect(store.getLatestGoal(userId: accountId)?.userId == accountId)
        #expect(store.fetchPendingEvents(ownerUserId: localId, limit: 10).isEmpty)
        let claimedEvent = try #require(store.fetchPendingEvents(ownerUserId: accountId, limit: 10).first)
        #expect(claimedEvent.eventId == originalEvent.eventId)
    }

    @Test func swiftClientSyncsThroughHTTPToPostgres() async throws {
        #if MATLOGG_SYNC_E2E
        let serverURL = URL(string: "http://127.0.0.1:4000")!
        var loginRequest = URLRequest(url: serverURL.appendingPathComponent("auth/dev-login"))
        loginRequest.httpMethod = "POST"
        loginRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        loginRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": "ios-client-e2e@integration.matlogg"
        ])
        let (loginData, loginResponse) = try await URLSession.shared.data(for: loginRequest)
        #expect((loginResponse as? HTTPURLResponse)?.statusCode == 201)

        struct LoginResponse: Decodable { let accessToken: String }
        let token = try JSONDecoder().decode(LoginResponse.self, from: loginData).accessToken
        let api = APIService(
            baseURL: serverURL.appendingPathComponent("v1").absoluteString,
            accessTokenProvider: { token },
            syncEnabled: { true }
        )
        let payload = try JSONSerialization.data(withJSONObject: [
            "id": Self.e2eProductId.uuidString,
            "name": "iOS E2E-produkt",
            "brand": "MatLogg test",
            "nutrientsPer100g": ["kcal": 42, "protein": 1, "carbs": 9, "fat": 0],
            "source": "user"
        ])
        let event = SyncEvent(
            eventId: Self.e2eEventId,
            type: "product.upsert",
            createdAt: Date(),
            entityId: Self.e2eProductId.uuidString,
            schemaVersion: 1,
            payload: payload,
            status: .pending,
            attemptCount: 0,
            lastAttemptAt: nil,
            nextRetryAt: nil,
            lastError: nil,
            ownerUserId: UUID()
        )

        let first = try await api.uploadEvents([event])
        #expect(first.ackedEventIds == [Self.e2eEventId])
        #expect(first.rejected.isEmpty)

        let replay = try await api.uploadEvents([event])
        #expect(replay.ackedEventIds == [Self.e2eEventId])
        #expect(replay.rejected.isEmpty)
        #endif
    }
    
    @Test func retryBackoffSkipsUntilReady() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let goal = Goal(
            userId: userId,
            goalType: "maintain",
            dailyCalories: 2100,
            proteinTargetG: 140,
            carbsTargetG: 260,
            fatTargetG: 70
        )
        try await db.saveGoal(goal)
        let pending = await db.fetchPendingEvents(limit: 50)
        guard let first = pending.first(where: { $0.entityId == goal.id.uuidString }) else {
            #expect(false)
            return
        }
        await db.markEventForRetry(first.eventId, error: "test", backoffSeconds: 60)
        let pendingAfter = await db.fetchPendingEvents(limit: 50)
        #expect(!pendingAfter.contains(where: { $0.eventId == first.eventId }))
    }

    @Test func updatingScannedProductPreservesExistingMealLog() async throws {
        let db = DatabaseService.shared
        let userId = UUID()
        let product = Product(
            name: "Gjenskannet testvare",
            barcodeEan: "test-\(UUID().uuidString)",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )
        let log = FoodLog(
            userId: userId,
            productId: product.id,
            mealType: "lunsj",
            amountG: 100,
            loggedDate: Calendar.current.startOfDay(for: Date()),
            calories: 200,
            proteinG: 10,
            carbsG: 20,
            fatG: 5
        )

        try await db.saveProduct(product, ownerUserId: userId)
        try await db.saveLog(log)
        try await db.saveProduct(product, ownerUserId: userId)

        let summary = await db.getTodaysSummary(userId: userId)
        #expect(summary.logs.contains { $0.id == log.id && $0.mealType == "lunsj" })
    }

    @Test func catalogCachePersistsWithoutCreatingSyncEvent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggCatalogCache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("catalog.sqlite"))
        let barcode = "1234567890123"
        let product = Product(
            id: Product.catalogID(source: "openfoodfacts", externalID: barcode),
            name: "Cachet produkt",
            barcodeEan: barcode,
            source: "openfoodfacts",
            caloriesPer100g: 100,
            proteinGPer100g: 2,
            carbsGPer100g: 20,
            fatGPer100g: 1,
            nutritionSource: .openFoodFacts,
            imageSource: .none,
            externalID: barcode,
            nutritionBasis: .per100g,
            fetchedAt: Date()
        )

        try store.cacheCatalogProduct(product)

        #expect(store.getProductByBarcode(barcode, ownerUserId: nil)?.id == product.id)
        #expect(store.pendingSyncCount() == 0)
    }

    @Test func userProductsAreOwnerScopedClaimedAndDeletedWithProfileData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggOwnedProduct-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("owned-product.sqlite"))
        let localOwner = UUID()
        let accountOwner = UUID()
        let unrelatedOwner = UUID()
        let barcode = "7099999999999"
        let product = Product(
            name: "Min vare",
            barcodeEan: barcode,
            source: "user",
            caloriesPer100g: 123,
            proteinGPer100g: 4,
            carbsGPer100g: 20,
            fatGPer100g: 3
        )

        try store.saveProduct(product, ownerUserId: localOwner)

        #expect(store.getProductByBarcode(barcode, ownerUserId: localOwner)?.id == product.id)
        #expect(store.getProductByBarcode(barcode, ownerUserId: unrelatedOwner) == nil)
        #expect(store.localDataSummary(ownerId: localOwner).products == 1)

        try store.claimLocalData(from: localOwner, to: accountOwner)

        #expect(store.getProductByBarcode(barcode, ownerUserId: localOwner) == nil)
        #expect(store.getProductByBarcode(barcode, ownerUserId: accountOwner)?.id == product.id)
        #expect(store.localDataSummary(ownerId: accountOwner).products == 1)

        try store.deleteLocalData(ownerId: accountOwner)

        #expect(store.getProductByBarcode(barcode, ownerUserId: accountOwner) == nil)
        #expect(store.localDataSummary(ownerId: accountOwner).products == 0)
    }

    @Test func productBatchLookupReturnsOnlyRequestedProducts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggProductBatch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("products.sqlite"))
        let requested = Product(name: "Forespurt", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 1)
        let omitted = Product(name: "Ikke forespurt", caloriesPer100g: 200, proteinGPer100g: 2, carbsGPer100g: 2, fatGPer100g: 2)
        try store.cacheCatalogProduct(requested)
        try store.cacheCatalogProduct(omitted)

        let products = store.getProducts([requested.id, UUID()])

        #expect(products.count == 1)
        #expect(products[requested.id]?.name == requested.name)
        #expect(products[omitted.id] == nil)
        #expect(store.pendingSyncCount() == 0)
    }

    @Test func localDatabaseUsesLatestFormalSchemaVersion() async {
        let version = await DatabaseService.shared.localSchemaVersion()
        #expect(version == LocalStore.latestSchemaVersion)
    }

    @Test func schemaVersionThreeAddsBarcodeIndexWithoutDeletingProducts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggSchemaV3-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("schema-v2.sqlite")

        let product = Product(
            name: "Eksisterende produkt",
            barcodeEan: "1234567890123",
            caloriesPer100g: 100,
            proteinGPer100g: 1,
            carbsGPer100g: 2,
            fatGPer100g: 3
        )
        var seededStore: LocalStore? = try LocalStore(databaseURL: url)
        try seededStore?.cacheCatalogProduct(product)
        seededStore = nil

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "DROP INDEX products_barcode_idx;", nil, nil, nil) == SQLITE_OK)
        try #require(sqlite3_exec(db, "PRAGMA user_version = 2;", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try LocalStore(databaseURL: url)
        #expect(store.schemaVersion() == LocalStore.latestSchemaVersion)
        #expect(store.getProduct(product.id)?.name == product.name)

        db = nil
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(
            db,
            "SELECT COUNT(*) FROM sqlite_master WHERE type = 'index' AND name = 'products_barcode_idx';",
            -1,
            &statement,
            nil
        ) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 1)
    }

    @Test func schemaVersionFourQuarantinesOwnerlessPendingEvents() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggSchemaV4-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("schema-v3.sqlite")
        let eventId = UUID()

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        let seedSQL = """
        CREATE TABLE products(id TEXT PRIMARY KEY, barcode TEXT, json BLOB);
        CREATE TABLE sync_queue(
            eventId TEXT PRIMARY KEY, type TEXT, createdAt REAL, entityId TEXT,
            schemaVersion INTEGER NOT NULL DEFAULT 1, payload BLOB, status TEXT,
            attemptCount INTEGER, lastAttemptAt REAL, nextRetryAt REAL, lastError TEXT
        );
        INSERT INTO sync_queue(eventId, type, createdAt, schemaVersion, payload, status, attemptCount)
        VALUES('\(eventId.uuidString)', 'goal.set', 1, 1, X'7B7D', 'pending', 0);
        PRAGMA user_version = 3;
        """
        try #require(sqlite3_exec(db, seedSQL, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let store = try LocalStore(databaseURL: url)
        #expect(store.schemaVersion() == LocalStore.latestSchemaVersion)
        #expect(store.quarantinedSyncCount() == 1)
        #expect(store.fetchPendingEvents(ownerUserId: UUID(), limit: 10).isEmpty)

        db = nil
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "SELECT status, lastError FROM sync_queue WHERE eventId = ?;", -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, eventId.uuidString, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        let status = try #require(sqlite3_column_text(statement, 0))
        let error = try #require(sqlite3_column_text(statement, 1))
        #expect(String(cString: status) == "quarantined")
        #expect(String(cString: error).contains("brukerbinding"))
    }

    @Test func unversionedDatabaseMigratesThroughEveryStageAndPreservesProduct() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggUnversionedMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("unversioned.sqlite")
        let product = Product(
            name: "Historisk produkt",
            barcodeEan: "9876543210123",
            caloriesPer100g: 120,
            proteinGPer100g: 4,
            carbsGPer100g: 20,
            fatGPer100g: 2
        )

        var seededStore: LocalStore? = try LocalStore(databaseURL: url)
        try seededStore?.cacheCatalogProduct(product)
        seededStore = nil

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "DROP INDEX products_barcode_idx;", nil, nil, nil) == SQLITE_OK)
        try #require(sqlite3_exec(db, "DROP TABLE saved_meals;", nil, nil, nil) == SQLITE_OK)
        try #require(sqlite3_exec(db, "PRAGMA user_version = 0;", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        let migrated = try LocalStore(databaseURL: url)
        #expect(migrated.schemaVersion() == LocalStore.latestSchemaVersion)
        #expect(migrated.getProduct(product.id)?.name == product.name)
        #expect(migrated.getSavedMeals(userId: UUID()).isEmpty)
    }

    @Test func schemaVersionSixMigratesAndReopensWithoutDeletingDrafts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggSchemaSix-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        var store: LocalStore? = try LocalStore(databaseURL: url)
        store = nil
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "DROP TABLE product_drafts; DROP TABLE catalog_submissions; PRAGMA user_version = 5;", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        store = try LocalStore(databaseURL: url)
        #expect(store?.schemaVersion() == 6)
        store = nil
        let owner = UUID()
        let otherOwner = UUID()
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        let seed = "INSERT INTO product_drafts VALUES ('one', '\(owner.uuidString)', 1, X'7B7D'); INSERT INTO product_drafts VALUES ('two', '\(otherOwner.uuidString)', 1, X'7B7D');"
        try #require(sqlite3_exec(db, seed, nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        store = try LocalStore(databaseURL: url)
        #expect(store?.schemaVersion() == 6)
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        func draftCount() throws -> Int {
            var statement: OpaquePointer?
            try #require(sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM product_drafts;", -1, &statement, nil) == SQLITE_OK)
            defer { sqlite3_finalize(statement) }
            try #require(sqlite3_step(statement) == SQLITE_ROW)
            return Int(sqlite3_column_int(statement, 0))
        }
        #expect(try draftCount() == 2)
        try store?.deleteLocalData(ownerId: owner)
        #expect(try draftCount() == 1)
        try store?.resetAllData()
        #expect(try draftCount() == 0)
    }

    @Test func newerSchemaReturnsControlledErrorInsteadOfOpeningStore() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggFutureSchema-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("future.sqlite")
        let futureVersion = LocalStore.latestSchemaVersion + 1

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "PRAGMA user_version = \(futureVersion);", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        do {
            _ = try LocalStore(databaseURL: url)
            Issue.record("Et nyere skjema skal ikke åpnes")
        } catch LocalStoreError.unsupportedSchema(let version) {
            #expect(version == futureVersion)
        } catch {
            Issue.record("Forventet unsupportedSchema, fikk \(error)")
        }
    }

    @MainActor
    @Test func unavailableDatabaseServiceRejectsWrites() async {
        let service = DatabaseService(
            storeResult: .failure(LocalStoreError.unsupportedSchema(LocalStore.latestSchemaVersion + 1))
        )
        let goal = Goal(
            userId: UUID(),
            goalType: "maintain",
            dailyCalories: 2_000,
            proteinTargetG: 100,
            carbsTargetG: 200,
            fatTargetG: 70
        )

        #expect(!service.isAvailable)
        do {
            try await service.saveGoal(goal)
            Issue.record("Skriving skal avvises når databasen ikke er tilgjengelig")
        } catch {
            #expect(error is DatabaseServiceError)
        }
    }

    @Test func failedMigrationRollsBackAndLeavesExistingSchemaVersionUntouched() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggMigrationRollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("broken-v2.sqlite")

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "CREATE TABLE products(id TEXT PRIMARY KEY);", nil, nil, nil) == SQLITE_OK)
        try #require(sqlite3_exec(db, "INSERT INTO products(id) VALUES('preserved');", nil, nil, nil) == SQLITE_OK)
        try #require(sqlite3_exec(db, "PRAGMA user_version = 2;", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        #expect(throws: (any Error).self) {
            _ = try LocalStore(databaseURL: url)
        }

        db = nil
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "SELECT id FROM products LIMIT 1;", -1, &statement, nil) == SQLITE_OK)
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        let preservedID = try #require(sqlite3_column_text(statement, 0))
        #expect(String(cString: preservedID) == "preserved")
        sqlite3_finalize(statement)

        statement = nil
        try #require(sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 2)
    }

    @Test func corruptStoredJSONEmitsDiagnosticWithoutDeletingRow() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggDecodeDiagnostic-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("decode.sqlite")
        var diagnostics: [LocalStoreDiagnostic] = []
        let store = try LocalStore(databaseURL: url) { diagnostics.append($0) }
        let product = Product(
            name: "Produkt",
            caloriesPer100g: 100,
            proteinGPer100g: 1,
            carbsGPer100g: 2,
            fatGPer100g: 3
        )
        try store.cacheCatalogProduct(product)

        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        try #require(sqlite3_exec(db, "UPDATE products SET json = X'7B';", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(db)

        #expect(store.getProduct(product.id) == nil)
        #expect(diagnostics.count == 1)
        guard case .decodingFailed(let entity, _) = diagnostics[0] else {
            Issue.record("Forventet dekodingsdiagnostikk")
            return
        }
        #expect(entity == "product")

        db = nil
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        try #require(sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM products;", -1, &statement, nil) == SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        try #require(sqlite3_step(statement) == SQLITE_ROW)
        #expect(sqlite3_column_int(statement, 0) == 1)
    }

    @Test func resetAllDataClearsDomainTablesAndSyncQueue() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MatLoggReset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("reset.sqlite"))
        let userId = UUID()
        let product = Product(name: "Slettes", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 1)
        try store.saveProduct(product, ownerUserId: userId)
        try store.saveGoal(Goal(userId: userId, goalType: "maintain", dailyCalories: 2000, proteinTargetG: 100, carbsTargetG: 200, fatTargetG: 60))
        #expect(store.pendingSyncCount() > 0)

        try store.resetAllData()

        #expect(store.getProduct(product.id) == nil)
        #expect(store.getLatestGoal(userId: userId) == nil)
        #expect(store.pendingSyncCount() == 0)
    }
}

@MainActor
struct LogViewModelTests {
    @Test func deletionFailureDoesNotOfferUndoAndLeavingDuringDeleteDoesNotReviveReceipt() async {
        let repository = FoodLogRepositorySpy()
        let vm = LogViewModel(repository: repository)
        let owner = UUID()
        let log = makeLog(userId: owner, productId: UUID(), date: Date())
        repository.deleteError = NSError(domain: "test", code: 1)
        #expect(!(await vm.deleteWithUndo(log, userId: owner)))
        #expect(vm.deletionReceiptID == nil)
        #expect(vm.errorMessage != nil)
        repository.deleteError = nil
        repository.deleteDelayNanoseconds = 30_000_000
        let deletion = Task { await vm.deleteWithUndo(log, userId: owner) }
        while !vm.isDeletingOrRestoring { await Task.yield() }
        #expect(!(await vm.undoDeletion(userId: owner)))
        vm.dismissDeletionReceipt()
        #expect(await deletion.value)
        #expect(vm.deletionReceiptID == nil)
        #expect(vm.deletedLogCount == 0)
    }

    @Test func deletionUndoPreservesSnapshotsAndGroupsRapidDeletes() async throws {
        let repository = FoodLogRepositorySpy()
        let vm = LogViewModel(repository: repository)
        let owner = UUID()
        let log = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj",
                          amountG: 123.45, amountUnit: .milliliters, loggedDate: Date(),
                          calories: 67.89, proteinG: 1.23, carbsG: 4.56, fatG: 7.89)
        let other = makeLog(userId: owner, productId: UUID(), date: Date())
        #expect(await vm.deleteWithUndo(log, userId: owner))
        #expect(await vm.deleteWithUndo(other, userId: owner))
        #expect(!(await vm.deleteWithUndo(log, userId: owner)))
        #expect(vm.deletedLogCount == 2)
        #expect(await vm.undoDeletion(userId: owner))
        let restored = try #require(repository.savedLogs.first)
        #expect(restored.id != log.id)
        #expect(restored.productId == log.productId)
        #expect(restored.amountG == log.amountG)
        #expect(restored.amountUnit == log.amountUnit)
        #expect(restored.loggedDate == log.loggedDate)
        #expect(restored.loggedTime == log.loggedTime)
        #expect(restored.createdAt == log.createdAt)
        #expect(restored.calories == log.calories)
        #expect(restored.proteinG == log.proteinG)
        #expect(restored.carbsG == log.carbsG)
        #expect(restored.fatG == log.fatG)
        #expect(!restored.isSynced)
        #expect(repository.savedLogs.count == 2)
        #expect(vm.deletionReceiptID == nil)
        #expect(!(await vm.undoDeletion(userId: owner)))
    }

    @Test func deletionUndoRetainsReceiptOnFailureAndRejectsOtherOwner() async {
        let repository = FoodLogRepositorySpy()
        let vm = LogViewModel(repository: repository)
        let owner = UUID()
        let log = makeLog(userId: owner, productId: UUID(), date: Date())
        #expect(!(await vm.deleteWithUndo(log, userId: UUID())))
        #expect(repository.deletedIds.isEmpty)
        #expect(await vm.deleteWithUndo(log, userId: owner))
        #expect(!(await vm.undoDeletion(userId: UUID())))
        #expect(repository.savedLogs.isEmpty)
        repository.saveError = NSError(domain: "test", code: 1)
        #expect(!(await vm.undoDeletion(userId: owner)))
        #expect(vm.deletionReceiptID != nil)
        #expect(vm.deletedLogCount == 1)
        repository.saveError = nil
        #expect(await vm.undoDeletion(userId: owner))
        #expect(repository.savedLogs.count == 1)
        #expect(await vm.deleteWithUndo(log, userId: owner))
        vm.dismissDeletionReceipt()
        #expect(!(await vm.undoDeletion(userId: owner)))
    }

    @Test func deleteAndRestorePersistSeparateOwnedSyncEventsOffline() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("undo.sqlite")
        let store = try LocalStore(databaseURL: url)
        let owner = UUID()
        let original = makeLog(userId: owner, productId: UUID(), date: Date())
        try store.saveLog(original)
        try store.deleteLog(original.id)
        #expect(store.getAllLogs(userId: owner).isEmpty)
        let restored = FoodLog(userId: owner, productId: original.productId, mealType: original.mealType,
                               amountG: original.amountG, amountUnit: original.resolvedAmountUnit,
                               loggedDate: original.loggedDate, loggedTime: original.loggedTime,
                               calories: original.calories, proteinG: original.proteinG,
                               carbsG: original.carbsG, fatG: original.fatG, createdAt: original.createdAt)
        try store.saveLogs([restored])
        let reopened = try LocalStore(databaseURL: url)
        #expect(reopened.getAllLogs(userId: owner).map(\.id) == [restored.id])
        let events = reopened.fetchPendingEvents(ownerUserId: owner, limit: 10)
        #expect(events.map(\.type) == ["log.upsert", "log.delete", "log.upsert"])
        #expect(events.last?.entityId == restored.id.uuidString)
        #expect(Set(events.map(\.eventId)).count == 3)
        #expect(events.allSatisfy { $0.ownerUserId == owner && $0.schemaVersion == 1 })
    }

    @Test func loadingSummaryPublishesBatchResolvedProductNames() async {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let product = Product(name: "Havregryn", caloriesPer100g: 370, proteinGPer100g: 13, carbsGPer100g: 60, fatGPer100g: 7)
        let log = makeLog(userId: userId, productId: product.id, date: Date())
        repository.products[product.id] = product
        repository.logs = [log]

        await viewModel.loadSelectedSummary(userId: userId, date: Date())

        #expect(viewModel.selectedProductNames[product.id] == "Havregryn")
    }

    @Test func latestSelectedDateWinsWhenSummaryRequestsCompleteOutOfOrder() async throws {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let calendar = Calendar(identifier: .gregorian)
        let firstDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20)))
        let secondDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21)))
        repository.summaryDelayNanoseconds = { date in
            calendar.isDate(date, inSameDayAs: firstDate) ? 100_000_000 : 0
        }

        let firstRequest = Task {
            await viewModel.loadSelectedSummary(userId: userId, date: firstDate, calendar: calendar)
        }
        await Task.yield()
        await viewModel.loadSelectedSummary(userId: userId, date: secondDate, calendar: calendar)
        await firstRequest.value

        let selectedDate = try #require(viewModel.selectedSummary?.date)
        #expect(calendar.isDate(selectedDate, inSameDayAs: secondDate))
    }

    @Test func loggingCalculatesNutritionAndPersistsThroughRepository() async {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let product = Product(
            name: "Testvare",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 50,
            mealType: "lunsj",
            userId: userId
        )

        #expect(succeeded)
        #expect(repository.savedLogs.count == 1)
        #expect(repository.savedLogs.first?.userId == userId)
        #expect(repository.savedLogs.first?.calories == 100)
        #expect(repository.savedLogs.first?.proteinG == 5)
    }

    @Test func fractionalCaloriesArePreservedUntilDailyDisplayRounding() async throws {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let product = Product(
            name: "Desimalvare",
            caloriesPer100g: 99.9,
            proteinGPer100g: 1.25,
            carbsGPer100g: 2.5,
            fatGPer100g: 0.75
        )

        for _ in 0..<3 {
            #expect(await viewModel.logFood(product: product, amountG: 50, mealType: "lunsj", userId: userId))
        }

        let totals = NutritionCalculator.totals(for: repository.savedLogs)
        #expect(abs(totals.calories - 149.85) < 0.001)
        #expect(NutritionDisplay.wholeCalories(totals.calories) == 150)
    }

    @Test func editingLogScalesHistoricalSnapshotWithoutChangingItsUnitBasis() async throws {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let original = FoodLog(
            userId: userId,
            productId: UUID(),
            mealType: "lunsj",
            amountG: 200,
            amountUnit: .milliliters,
            loggedDate: Date(),
            calories: 101.5,
            proteinG: 2.5,
            carbsG: 20,
            fatG: 1
        )

        #expect(await viewModel.updateLog(original, amountG: 100, mealType: "lunsj", userId: userId))
        let updated = try #require(repository.savedLogs.first)
        #expect(updated.resolvedAmountUnit == .milliliters)
        #expect(abs(updated.calories - 50.75) < 0.001)
        #expect(abs(updated.carbsG - 10) < 0.001)
    }

    @Test func repositoryFailureBecomesViewModelErrorState() async {
        let repository = FoodLogRepositorySpy()
        repository.saveError = TestRepositoryError.saveFailed
        let viewModel = LogViewModel(repository: repository)
        let product = Product(
            name: "Testvare",
            caloriesPer100g: 100,
            proteinGPer100g: 1,
            carbsGPer100g: 1,
            fatGPer100g: 1
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 100,
            mealType: "middag",
            userId: UUID()
        )

        #expect(!succeeded)
        #expect(viewModel.errorMessage?.hasPrefix("Kunne ikke lagre logging:") == true)
    }

    @Test func loggingUsesTheSelectedHistoricalDate() async throws {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDate = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 18, hour: 14, minute: 35))
        )
        let product = Product(
            name: "Historisk testvare",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 100,
            mealType: "middag",
            userId: UUID(),
            date: selectedDate
        )

        let savedLog = try #require(repository.savedLogs.first)
        #expect(succeeded)
        #expect(calendar.isDate(savedLog.loggedDate, inSameDayAs: selectedDate))
        #expect(savedLog.loggedTime == selectedDate)
        #expect(viewModel.mutationRevision == 1)
    }

    @Test func loggingUsesTheSelectedFutureDate() async throws {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDate = try #require(calendar.date(byAdding: .day, value: 7, to: Date()))
        let product = Product(
            name: "Fremtidig testvare",
            caloriesPer100g: 200,
            proteinGPer100g: 10,
            carbsGPer100g: 20,
            fatGPer100g: 5
        )

        let succeeded = await viewModel.logFood(
            product: product,
            amountG: 100,
            mealType: "middag",
            userId: UUID(),
            date: selectedDate
        )

        let savedLog = try #require(repository.savedLogs.first)
        #expect(succeeded)
        #expect(calendar.isDate(savedLog.loggedDate, inSameDayAs: selectedDate))
        #expect(savedLog.loggedTime == selectedDate)
    }

    @Test func undoDeletesTheLatestMatchingLog() async {
        let repository = FoodLogRepositorySpy()
        let viewModel = LogViewModel(repository: repository)
        let userId = UUID()
        let productId = UUID()
        let day = Date()
        let older = makeLog(userId: userId, productId: productId, date: day.addingTimeInterval(-60))
        let latest = makeLog(userId: userId, productId: productId, date: day)
        repository.logs = [older, latest]

        let succeeded = await viewModel.undoLatestLog(
            productId: productId,
            mealType: "lunsj",
            amountG: 100,
            userId: userId,
            date: day
        )

        #expect(succeeded)
        #expect(repository.deletedIds == [latest.id])
    }

    private func makeLog(userId: UUID, productId: UUID, date: Date) -> FoodLog {
        FoodLog(
            userId: userId,
            productId: productId,
            mealType: "lunsj",
            amountG: 100,
            loggedDate: date,
            loggedTime: date,
            calories: 100,
            proteinG: 1,
            carbsG: 1,
            fatG: 1
        )
    }
}

private enum TestRepositoryError: Error {
    case saveFailed
}

private final class FoodLogRepositorySpy: FoodLogRepository {
    var savedLogs: [FoodLog] = []
    var deletedIds: [UUID] = []
    var logs: [FoodLog] = []
    var products: [UUID: Product] = [:]
    var deleteError: Error?
    var deleteDelayNanoseconds: UInt64 = 0
    var saveError: Error?
    var summaryDelayNanoseconds: ((Date) -> UInt64)?

    func saveLogs(_ logs: [FoodLog]) async throws {
        if let saveError { throw saveError }
        savedLogs.append(contentsOf: logs)
    }

    func deleteLogs(_ ids: [UUID]) async throws {
        deletedIds.append(contentsOf: ids)
    }

    func saveLog(_ log: FoodLog) async throws {
        if let saveError { throw saveError }
        savedLogs.append(log)
    }

    func deleteLog(_ id: UUID) async throws {
        if deleteDelayNanoseconds > 0 { try await Task.sleep(nanoseconds: deleteDelayNanoseconds) }
        if let deleteError { throw deleteError }
        deletedIds.append(id)
    }

    func getAllLogs(userId: UUID) async -> [FoodLog] {
        logs.filter { $0.userId == userId }
    }

    func getSummary(userId: UUID, date: Date) async -> DailySummary {
        if let delay = summaryDelayNanoseconds?(date), delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }
        let matching = logs.filter {
            $0.userId == userId && Calendar.current.isDate($0.loggedDate, inSameDayAs: date)
        }
        return summary(date: date, logs: matching)
    }

    func getTodaysSummary(userId: UUID) async -> DailySummary {
        await getSummary(userId: userId, date: Date())
    }

    func getProduct(_ id: UUID) -> Product? {
        products[id]
    }

    private func summary(date: Date, logs: [FoodLog]) -> DailySummary {
        DailySummary(
            date: date,
            totalCalories: logs.reduce(0) { $0 + $1.calories },
            totalProtein: logs.reduce(0) { $0 + $1.proteinG },
            totalCarbs: logs.reduce(0) { $0 + $1.carbsG },
            totalFat: logs.reduce(0) { $0 + $1.fatG },
            logs: logs
        )
    }
}

@MainActor
struct HealthProfileViewModelTests {
    @Test func savingGoalUpdatesPublishedGoal() async {
        let repository = HealthProfileRepositorySpy()
        let viewModel = HealthProfileViewModel(
            repository: repository,
            personalDetailsStore: PersonalDetailsStoreSpy()
        )
        let goal = Goal(
            userId: UUID(),
            goalType: "maintain",
            dailyCalories: 2000,
            proteinTargetG: 120,
            carbsTargetG: 250,
            fatTargetG: 70
        )

        let succeeded = await viewModel.saveGoal(goal)

        #expect(succeeded)
        #expect(viewModel.currentGoal?.id == goal.id)
        #expect(repository.savedGoals.map(\.id) == [goal.id])
    }

    @Test func weightFromAnotherUserCannotBeDeleted() async {
        let repository = HealthProfileRepositorySpy()
        let viewModel = HealthProfileViewModel(
            repository: repository,
            personalDetailsStore: PersonalDetailsStoreSpy()
        )
        let entry = WeightEntry(userId: UUID(), date: Date(), weightKg: 75)

        let succeeded = await viewModel.deleteWeight(entry, userId: UUID())

        #expect(!succeeded)
        #expect(repository.deletedWeightIds.isEmpty)
    }
}

private final class HealthProfileRepositorySpy: HealthProfileRepository {
    var savedGoals: [Goal] = []
    var deletedWeightIds: [UUID] = []
    var weights: [WeightEntry] = []

    func saveGoal(_ goal: Goal) async throws {
        savedGoals.append(goal)
    }

    func latestGoal(userId: UUID) async -> Goal? {
        savedGoals.last { $0.userId == userId }
    }

    func saveWeightEntry(_ entry: WeightEntry) async throws {
        weights.append(entry)
    }

    func deleteWeightEntry(_ id: UUID) async throws {
        deletedWeightIds.append(id)
    }

    func getWeightEntries(userId: UUID) async -> [WeightEntry] {
        weights.filter { $0.userId == userId }
    }
}

private final class PersonalDetailsStoreSpy: PersonalDetailsStore {
    var details: PersonalDetails = .empty

    func load(userId: UUID) -> PersonalDetails {
        details
    }

    func save(_ details: PersonalDetails, userId: UUID) throws {
        self.details = details
    }
}

@MainActor
struct AuthViewModelTests {
    @Test func restoreSessionPublishesOnlyAValidatedRepositoryUser() async {
        let user = makeUser()
        let repository = AccountAuthRepositorySpy()
        repository.restoredUser = user
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(
            authRepository: repository,
            localStore: store,
            localProfileManager: LocalProfileManagerSpy()
        )

        #expect(viewModel.isRestoringSession)
        await viewModel.restoreSession()

        #expect(!viewModel.isRestoringSession)
        #expect(viewModel.authenticatedUser?.id == user.id)
        #expect(store.user?.id == user.id)
    }

    @Test func sessionRequiresBothStoredUserAndToken() {
        let user = makeUser()
        let incompleteStore = AuthSessionStoreSpy(user: user, token: nil)

        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user),
            sessionStore: incompleteStore
        )

        #expect(viewModel.currentUser == nil)
        if case .notAuthenticated = viewModel.authState {
            #expect(true)
        } else {
            #expect(false)
        }
    }

    @Test func loginPersistsSessionAndAuthenticatesUser() async {
        let user = makeUser()
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user, token: "test-token"),
            sessionStore: store
        )

        await viewModel.login(email: user.email, password: "password")

        #expect(viewModel.currentUser?.id == user.id)
        #expect(store.user?.id == user.id)
        #expect(store.token == "test-token")
        #expect(!viewModel.isLoading)
    }

    @Test func localProfileCanBeUsedWithoutCredentials() {
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(apiClient: AuthAPIClientSpy(user: makeUser()), sessionStore: store)

        viewModel.continueLocally()

        #expect(viewModel.currentUser?.isLocalProfile == true)
        #expect(viewModel.authenticatedUser == nil)
        #expect(store.token == nil)
        #expect(viewModel.isOnboarding)
    }

    @Test func accountLoginWaitsForConfirmationBeforeClaimingLocalData() async {
        let account = makeUser()
        let store = AuthSessionStoreSpy()
        let manager = LocalProfileManagerSpy()
        manager.summary = LocalDataSummary(logs: 2, goals: 1, favorites: 0, scans: 0, weights: 0, savedMeals: 0, products: 0)
        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: account),
            sessionStore: store,
            localProfileManager: manager
        )
        viewModel.continueLocally()
        let localId = viewModel.currentUser?.id

        await viewModel.login(email: account.email, password: "password")

        #expect(viewModel.currentUser?.id == localId)
        #expect(viewModel.pendingLocalDataSummary?.logs == 2)
        #expect(manager.claimedFrom == nil)
        #expect(manager.claimedTo == nil)
        #expect(store.token == "token")
        await viewModel.confirmLocalDataLink()
        #expect(manager.claimedFrom == localId)
        #expect(manager.claimedTo == account.id)
        #expect(viewModel.authenticatedUser?.id == account.id)
        #expect(store.token == "token")
    }

    @Test func loginDoesNotAuthenticateWhenTokenCannotBeStored() async {
        let user = makeUser()
        let store = AuthSessionStoreSpy(tokenStorageSucceeds: false)
        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user, token: "test-token"),
            sessionStore: store
        )

        await viewModel.login(email: user.email, password: "password")

        #expect(viewModel.currentUser == nil)
        #expect(store.user == nil)
        #expect(store.token == nil)
        #expect(viewModel.errorMessage == "Innloggingen kunne ikke lagres sikkert på enheten. Prøv igjen.")
        if case .error = viewModel.authState {
            #expect(true)
        } else {
            #expect(false)
        }
    }

    @Test func debugSessionKeepsSameIdentityAcrossAppRestarts() {
        let first = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: makeUser()),
            sessionStore: AuthSessionStoreSpy()
        )
        let restarted = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: makeUser()),
            sessionStore: AuthSessionStoreSpy()
        )

        first.enableDebugSession()
        restarted.enableDebugSession()

        #expect(first.currentUser?.id == restarted.currentUser?.id)
        #expect(first.currentUser?.authProvider == "debug")
    }

    @Test func expiredSessionClearsCredentialsAndShowsLoginMessage() {
        let user = makeUser()
        let store = AuthSessionStoreSpy(user: user, token: "expired-token")
        let viewModel = AuthViewModel(
            apiClient: AuthAPIClientSpy(user: user),
            sessionStore: store
        )

        viewModel.handleSessionExpired()

        #expect(viewModel.currentUser == nil)
        #expect(store.token == nil)
        #expect(viewModel.errorMessage == "Økten din er utløpt. Logg inn på nytt. Dataene på denne enheten er beholdt.")
    }

    @Test func successfulAccountDeletionClearsLocalDataAndCredentials() async {
        let user = makeUser()
        let api = AuthAPIClientSpy(user: user)
        let store = AuthSessionStoreSpy(user: user, token: "token")
        let resetter = LocalProfileManagerSpy()
        let viewModel = AuthViewModel(apiClient: api, sessionStore: store, localProfileManager: resetter)
        await viewModel.restoreSession()

        let succeeded = await viewModel.deleteAccount()

        #expect(succeeded)
        #expect(api.deleteCallCount == 1)
        #expect(resetter.deleteCallCount == 1)
        #expect(store.user == nil)
        #expect(store.token == nil)
    }

    @Test func failedAccountDeletionPreservesLocalDataAndSession() async {
        let user = makeUser()
        let api = AuthAPIClientSpy(user: user)
        api.deleteError = TestRepositoryError.saveFailed
        let store = AuthSessionStoreSpy(user: user, token: "token")
        let resetter = LocalProfileManagerSpy()
        let viewModel = AuthViewModel(apiClient: api, sessionStore: store, localProfileManager: resetter)
        await viewModel.restoreSession()

        let succeeded = await viewModel.deleteAccount()

        #expect(!succeeded)
        #expect(resetter.deleteCallCount == 0)
        #expect(store.user?.id == user.id)
        #expect(store.token == "token")
        #expect(viewModel.errorMessage != nil)
    }

    @Test func signupWaitsForVerifiedEmailBeforeCreatingAccountSession() async {
        let repository = AccountAuthRepositorySpy()
        repository.registrationResult = .pendingEmailVerification(email: "test@example.com")
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(
            authRepository: repository,
            localStore: store,
            localProfileManager: LocalProfileManagerSpy()
        )

        await viewModel.signUp(email: "test@example.com", password: "password")

        #expect(viewModel.pendingVerificationEmail == "test@example.com")
        #expect(viewModel.currentUser == nil)
        #expect(store.user == nil)
    }

    @Test func resendUsesPendingVerificationAddress() async {
        let repository = AccountAuthRepositorySpy()
        repository.registrationResult = .pendingEmailVerification(email: "test@example.com")
        let viewModel = AuthViewModel(
            authRepository: repository,
            localStore: AuthSessionStoreSpy(),
            localProfileManager: LocalProfileManagerSpy()
        )

        await viewModel.signUp(email: "test@example.com", password: "password")
        await viewModel.resendEmailVerification()

        #expect(repository.resentAddress == "test@example.com")
        #expect(viewModel.verificationMessage == "En ny bekreftelseslenke er sendt.")
    }

    @Test func emailCallbackCreatesVerifiedSession() async {
        let user = makeUser()
        let repository = AccountAuthRepositorySpy()
        repository.registrationResult = .pendingEmailVerification(email: user.email)
        repository.callbackUser = user
        let store = AuthSessionStoreSpy()
        let viewModel = AuthViewModel(
            authRepository: repository,
            localStore: store,
            localProfileManager: LocalProfileManagerSpy()
        )

        await viewModel.signUp(email: user.email, password: "password")
        await viewModel.handleAuthCallback(URL(string: "matlogg://auth/callback?code=test")!)

        #expect(viewModel.pendingVerificationEmail == nil)
        #expect(viewModel.currentUser?.id == user.id)
        #expect(store.user?.id == user.id)
        #expect(viewModel.isOnboarding)
    }

    private func makeUser() -> User {
        User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User",
            authProvider: "email",
            createdAt: Date()
        )
    }
}

@MainActor
private final class AccountAuthRepositorySpy: AccountAuthRepository {
    var registrationResult: AccountRegistrationResult?
    var callbackUser: User?
    var restoredUser: User?
    var resentAddress: String?

    func restoreSession() async -> User? { restoredUser }
    func signIn(email: String, password: String) async throws -> User {
        guard let callbackUser else { throw TestRepositoryError.saveFailed }
        return callbackUser
    }
    func signUp(email: String, password: String) async throws -> AccountRegistrationResult {
        guard let registrationResult else { throw TestRepositoryError.saveFailed }
        return registrationResult
    }
    func resendEmailVerification(to email: String) async throws { resentAddress = email }
    func signInWithApple(identityToken: String, nonce: String) async throws -> User {
        guard let callbackUser else { throw TestRepositoryError.saveFailed }
        return callbackUser
    }
    func handleAuthCallback(_ url: URL) async throws -> User {
        guard let callbackUser else { throw TestRepositoryError.saveFailed }
        return callbackUser
    }
    func signOut() async throws {}
    func deleteAccount() async throws -> AccountDeletionReceipt {
        AccountDeletionReceipt(
            code: "ACCOUNT_PENDING_DELETION",
            message: "Kontoen er markert for sletting",
            permanentDeletionAt: Date().addingTimeInterval(30 * 86_400)
        )
    }
}

private final class AuthAPIClientSpy: AuthAPIClient {
    let user: User
    let tokens: AuthTokens
    var deleteCallCount = 0
    var deleteError: Error?

    init(user: User, token: String = "token") {
        self.user = user
        self.tokens = AuthTokens(accessToken: token, refreshToken: "refresh-token")
    }

    func loginEmail(email: String, password: String) async throws -> (User, AuthTokens) {
        (user, tokens)
    }

    func signupEmail(email: String, password: String) async throws -> (User, AuthTokens) {
        (user, tokens)
    }

    func loginApple(identityToken: String, authorizationCode: String?, nonce: String) async throws -> (User, AuthTokens) {
        (user, tokens)
    }

    func revokeRefreshToken(_ refreshToken: String) async throws {}

    func deleteAccount() async throws -> AccountDeletionReceipt {
        deleteCallCount += 1
        if let deleteError { throw deleteError }
        return AccountDeletionReceipt(
            code: "ACCOUNT_PENDING_DELETION",
            message: "Kontoen er markert for sletting",
            permanentDeletionAt: Date().addingTimeInterval(30 * 86_400)
        )
    }
}

private final class LocalProfileManagerSpy: LocalProfileManaging {
    var deleteCallCount = 0
    var summary: LocalDataSummary = .empty
    var claimedFrom: UUID?
    var claimedTo: UUID?

    func localDataSummary(ownerId: UUID) async -> LocalDataSummary { summary }
    func claimLocalData(from localOwnerId: UUID, to accountOwnerId: UUID) async throws {
        claimedFrom = localOwnerId
        claimedTo = accountOwnerId
    }
    func deleteLocalData(ownerId: UUID) async throws { deleteCallCount += 1 }
}

@MainActor
struct AppStateTests {
    @Test func defaultMealFollowsLocalHourBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let base = DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 9, day: 16)
        func date(_ hour: Int) -> Date {
            var components = base
            components.hour = hour
            return calendar.date(from: components)!
        }

        #expect(AppState.defaultMealType(at: date(5), calendar: calendar) == "frokost")
        #expect(AppState.defaultMealType(at: date(10), calendar: calendar) == "frokost")
        #expect(AppState.defaultMealType(at: date(11), calendar: calendar) == "lunsj")
        #expect(AppState.defaultMealType(at: date(16), calendar: calendar) == "middag")
        #expect(AppState.defaultMealType(at: date(21), calendar: calendar) == "snacks")
        #expect(AppState.defaultMealType(at: date(4), calendar: calendar) == "snacks")
    }
}

private final class AuthSessionStoreSpy: AuthSessionStore {
    var user: User?
    var token: String?
    var tokenStorageSucceeds: Bool
    var refreshToken: String?
    var localUser: User?
    var onboardingCompleted: Set<UUID> = []

    init(user: User? = nil, token: String? = nil, tokenStorageSucceeds: Bool = true) {
        self.user = user
        self.token = token
        self.refreshToken = token == nil ? nil : "refresh-token"
        self.tokenStorageSucceeds = tokenStorageSucceeds
    }

    func storeUser(_ user: User) {
        self.user = user
    }

    func getStoredUser() -> User? {
        user
    }

    @discardableResult
    func storeToken(_ token: String) -> Bool {
        if tokenStorageSucceeds {
            self.token = token
        }
        return tokenStorageSucceeds
    }

    func getStoredToken() -> String? {
        token
    }

    @discardableResult
    func storeTokens(_ tokens: AuthTokens) -> Bool {
        guard tokenStorageSucceeds else { return false }
        token = tokens.accessToken
        refreshToken = tokens.refreshToken
        return true
    }

    func getStoredRefreshToken() -> String? {
        refreshToken
    }

    @discardableResult
    func clearStoredCredentials() -> Bool {
        user = nil
        token = nil
        refreshToken = nil
        return true
    }

    func activateLocalProfile() -> User {
        if let localUser { return localUser }
        let created = User.local(id: UUID())
        localUser = created
        return created
    }

    func getActiveLocalProfile() -> User? { localUser }
    func consumeLocalProfile() { localUser = nil }
    func deactivateLocalMode() {}
    func hasCompletedOnboarding(userId: UUID) -> Bool { onboardingCompleted.contains(userId) }
    func onboardingCompletion(userId: UUID) -> Bool? { onboardingCompleted.contains(userId) ? true : nil }
    func setOnboardingCompleted(_ completed: Bool, userId: UUID) {
        if completed { onboardingCompleted.insert(userId) } else { onboardingCompleted.remove(userId) }
    }
}

@MainActor
struct ManualProductViewModelTests {
    @Test @MainActor func rejectsProductNameAboveMaximumLength() async {
        var didSave = false
        let viewModel = ManualProductViewModel(barcode: nil) { _ in
            didSave = true
        }
        viewModel.name = String(repeating: "a", count: ManualProductViewModel.maximumNameLength + 1)
        viewModel.calories = "100"
        viewModel.protein = "10"
        viewModel.carbs = "20"
        viewModel.fat = "5"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(didSave == false)
        #expect(viewModel.errorMessage?.contains("maksimalt") == true)
    }

    @Test func savesUserEnteredNutritionWithoutEstimatingValues() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: "7038010054821") { product in
            savedProducts.append(product)
        }
        viewModel.name = "  Testbrød  "
        viewModel.calories = "241"
        viewModel.protein = "8,5"
        viewModel.carbs = "42.25"
        viewModel.fat = "3"

        let product = await viewModel.save()

        #expect(product?.name == "Testbrød")
        #expect(product?.barcodeEan == "7038010054821")
        #expect(product?.nutritionSource == .user)
        #expect(product?.verificationStatus == .unverified)
        #expect(product?.proteinGPer100g == 8.5)
        #expect(product?.carbsGPer100g == 42.25)
        #expect(savedProducts.map(\.id) == [product?.id].compactMap { $0 })
    }

    @Test func missingNutritionIsRejectedInsteadOfDefaultingToZero() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: nil) { product in
            savedProducts.append(product)
        }
        viewModel.name = "Testvare"
        viewModel.calories = "100"
        viewModel.protein = ""
        viewModel.carbs = "10"
        viewModel.fat = "5"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(savedProducts.isEmpty)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func impossibleMacroTotalIsRejected() async {
        var savedProducts: [Product] = []
        let viewModel = ManualProductViewModel(barcode: nil) { product in
            savedProducts.append(product)
        }
        viewModel.name = "Testvare"
        viewModel.calories = "500"
        viewModel.protein = "50"
        viewModel.carbs = "50"
        viewModel.fat = "10"

        let product = await viewModel.save()

        #expect(product == nil)
        #expect(savedProducts.isEmpty)
        #expect(viewModel.errorMessage?.contains("ikke overstige 100") == true)
    }
}
