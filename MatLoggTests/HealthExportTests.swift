import Foundation
import HealthKit
import SQLite3
import Testing
@testable import MatLogg

@MainActor
struct HealthExportTests {
    private func withStore(_ operation: (LocalStore, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("health-export.sqlite")
        let store = try LocalStore(databaseURL: url, healthWritesEnabled: true)
        try await operation(store, url)
    }
    private func settings() -> HealthIntegrationSettings {
        var settings = HealthIntegrationSettings()
        settings.connectionID = UUID()
        settings.shareNutrition = true
        settings.shareWeight = true
        return settings
    }
    private func log(owner: UUID, id: UUID = UUID(), calories: Float = 123.25) -> FoodLog {
        FoodLog(id: id, userId: owner, productId: UUID(), mealType: "frokost", amountG: 75,
                loggedDate: Date(), calories: calories, proteinG: 4.5, carbsG: 12.25, fatG: 3)
    }
    @Test func pastDiaryDateControlsExportDayInsteadOfCreationDay() async throws {
        try await withStore { store, _ in
            let owner = UUID()
            let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
            let entry = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                loggedDate: Calendar.current.startOfDay(for: yesterday), loggedTime: Date(),
                calories: 100, proteinG: 10, carbsG: 5, fatG: 2)
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveLogs([entry])
            let records = try store.healthExports(owner: owner)
            #expect(records.count == 4)
            #expect(records.allSatisfy { $0.timestamp.map { Calendar.current.isDate($0, inSameDayAs: yesterday) } == true })
        }
    }
    @Test func knownSourceSurvivesLocalJSONReopenRetryAndNativeConversion() async throws {
        try await withStore { store, url in
            let owner = UUID()
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(log(owner: owner))) as? [String: Any])
            json["nutritionSource"] = "matvaretabellen"
            let entry = try JSONDecoder().decode(FoodLog.self, from: JSONSerialization.data(withJSONObject: json))
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveLogs([entry])
            let reopened = try LocalStore(databaseURL: url)
            let record = try #require(reopened.healthExports(owner: owner).first)
            #expect(record.nutritionSource == .matvaretabellen)
            let sample = try AppleHealthKitClient.makeSample(record)
            #expect(sample.metadata?["MatLoggNutritionSource"] as? String == "matvaretabellen")
        }
    }
    @Test func legacySourceStaysUnknownAndDoesNotChangeSyncContract() async throws {
        try await withStore { store, _ in
            let owner = UUID(), original = log(owner: UUID())
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
            json.removeValue(forKey: "nutritionSource")
            let legacy = try JSONDecoder().decode(FoodLog.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(legacy.nutritionSource == nil)
            try store.setHealthSettings(settings(), owner: legacy.userId)
            try store.saveLogs([legacy])
            #expect(try store.healthExports(owner: legacy.userId).allSatisfy { $0.nutritionSource == nil })
            let known = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
                nutritionSource: .user, loggedDate: Date(), calories: 100, proteinG: 1, carbsG: 2, fatG: 3)
            try store.saveLogs([known])
            let event = try #require(store.fetchPendingEvents(ownerUserId: owner, limit: 10).first)
            let payload = try #require(JSONSerialization.jsonObject(with: event.payload) as? [String: Any])
            #expect(payload["nutritionSource"] == nil && event.schemaVersion == 1)
        }
    }
    @Test func exportDateHandlesDSTAndPreservesAnExistingInstant() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))
        let day = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29)))
        let clock = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 2, minute: 30)))
        let entry = FoodLog(userId: UUID(), productId: UUID(), mealType: "lunsj", amountG: 100,
            loggedDate: day, loggedTime: clock, calories: 100, proteinG: 1, carbsG: 2, fatG: 3)
        #expect(calendar.isDate(entry.healthExportTimestamp(calendar: calendar), inSameDayAs: day))
        let actual = log(owner: UUID())
        #expect(actual.healthExportTimestamp(calendar: calendar) == actual.loggedTime)
    }
    @Test func sourceSnapshotSurvivesCatalogChangeEditCopyDeleteAndUndo() async throws {
        try await withStore { store, _ in
            let owner = UUID(), id = UUID(), today = Date()
            let yesterday = try #require(Calendar.current.date(byAdding: .day, value: -1, to: today))
            let product = Product(id: id, name: "Kildetest", caloriesPer100g: 100,
                proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3, nutritionSource: .openFoodFacts)
            try store.cacheCatalogProduct(product)
            try store.setHealthSettings(settings(), owner: owner)
            let model = LogViewModel(repository: DatabaseService(store: store))
            #expect(await model.logFood(product: product, amountG: 100, mealType: "lunsj", userId: owner, date: today))
            let original = try #require(store.getAllLogs(userId: owner).first)
            try store.cacheCatalogProduct(Product(id: id, name: "Oppdatert katalog", caloriesPer100g: 900,
                proteinGPer100g: 9, carbsGPer100g: 9, fatGPer100g: 9, nutritionSource: .user))
            #expect(await model.updateLog(original, amountG: 50, mealType: "lunsj", userId: owner))
            #expect(await model.copyLogs(from: today, to: yesterday, userId: owner))
            let copy = try #require(store.getAllLogs(userId: owner).first { Calendar.current.isDate($0.loggedDate, inSameDayAs: yesterday) })
            #expect(copy.nutritionSource == .openFoodFacts && copy.calories == 50)
            #expect(await model.deleteWithUndo(copy, userId: owner))
            #expect(await model.undoDeletion(userId: owner))
            #expect(store.getAllLogs(userId: owner).allSatisfy { $0.nutritionSource == .openFoodFacts })
            #expect(try store.healthExports(owner: owner).filter { !$0.isDeletion }.allSatisfy { $0.nutritionSource == .openFoodFacts })
        }
    }
    @Test func optInDoesNotExportHistoryOrOtherOwners() async throws {
        try await withStore { store, url in
            let owner = UUID()
            try store.saveLogs([log(owner: owner)])
            try store.setHealthSettings(settings(), owner: owner)
            #expect(try store.healthExports(owner: owner).isEmpty)
            try store.saveLogs([log(owner: UUID())])
            #expect(try store.healthExports(owner: owner).isEmpty)
            let disabled = try LocalStore(databaseURL: url, healthWritesEnabled: false)
            try disabled.saveLogs([log(owner: owner)])
            #expect(try store.healthExports(owner: owner).isEmpty)
        }
    }
    @Test func editUsesStableIdentityAndOldAcknowledgementCannotLoseNewEdit() async throws {
        try await withStore { store, url in
            let owner = UUID(), id = UUID()
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveLogs([log(owner: owner, id: id)])
            let original = try #require(store.healthExports(owner: owner).first { $0.kind == .energy })
            try store.saveLogs([log(owner: owner, id: id, calories: 246.5)])
            try store.completeHealthExport(original, owner: owner, at: Date())
            let edited = try #require(try store.healthExport(id: original.id, owner: owner))
            #expect(edited.pending && edited.revision == original.revision + 1)
            #expect(edited.value == 246.5 && edited.eventID != original.eventID)
            let reopened = try LocalStore(databaseURL: url)
            #expect(try reopened.healthExport(id: edited.id, owner: owner)?.eventID == edited.eventID)
            try store.completeHealthExport(edited, owner: owner, at: Date())
            let complete = try #require(try store.healthExport(id: edited.id, owner: owner))
            #expect(!complete.pending && complete.value == nil && complete.timestamp == nil)
        }
    }
    @Test func deletionAndUndoReuseIdentitiesWithIncreasingRevisions() async throws {
        try await withStore { store, _ in
            let owner = UUID(), entry = log(owner: UUID())
            let saved = log(owner: owner, id: entry.id)
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveLogs([saved])
            let before = try store.healthExports(owner: owner)
            try store.deleteLogs([saved.id])
            let deleted = try store.healthExports(owner: owner)
            #expect(deleted.count == 4 && deleted.allSatisfy { $0.isDeletion && $0.pending && $0.value == nil })
            try store.saveLogs([saved])
            let restored = try store.healthExports(owner: owner)
            #expect(Set(restored.map(\.id)) == Set(before.map(\.id)))
            #expect(restored.allSatisfy { !$0.isDeletion && $0.revision == 3 })
        }
    }
    @Test func failingMealRollsBackDomainSyncAndHealthTogether() async throws {
        try await withStore { store, _ in
            let owner = UUID()
            try store.setHealthSettings(settings(), owner: owner)
            do {
                try store.saveLogs([log(owner: owner), log(owner: owner, calories: -.infinity)])
                Issue.record("Invalid sample should fail the whole transaction")
            } catch {}
            #expect(store.getAllLogs(userId: owner).isEmpty)
            #expect(try store.healthExports(owner: owner).isEmpty)
            #expect(store.fetchPendingEvents(ownerUserId: owner, limit: 50).isEmpty)
        }
    }
    @Test func sameDayWeightEditKeepsExportIdentity() async throws {
        try await withStore { store, _ in
            let owner = UUID(), day = Date()
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveWeightEntry(WeightEntry(userId: owner, date: day, weightKg: 70.25))
            let first = try #require(store.healthExports(owner: owner).first)
            try store.saveWeightEntry(WeightEntry(userId: owner, date: day, weightKg: 71.5))
            let second = try #require(store.healthExports(owner: owner).first)
            #expect(first.id == second.id && second.revision == 2 && second.value == 71.5)
            let weight = try #require(store.getWeightEntries(userId: owner).first)
            try store.deleteWeightEntry(weight.id)
            #expect(try store.healthExports(owner: owner).first?.isDeletion == true)
        }
    }
    @Test func deniedTypeDoesNotBlockOtherNutrientsAndRetryIsIdempotent() async throws {
        try await withStore { store, _ in
            let owner = UUID(), client = ExportTestClient()
            client.denied = [.protein]
            let repository = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: client, enabled: { true })
            repository.selectOwner(owner)
            try await repository.connect(owner: owner, choices: settings())
            try store.saveLogs([log(owner: owner)])
            try await repository.refresh(owner: owner)
            #expect(client.saved.count == 3)
            #expect(try store.healthExports(owner: owner).filter(\.pending).count == 1)
            client.denied = []
            try await repository.refresh(owner: owner)
            try await repository.refresh(owner: owner)
            #expect(client.saved.count == 4 && client.saveCalls == 4)
            #expect(try store.healthExports(owner: owner).allSatisfy { !$0.pending })
        }
    }
    @Test func disconnectStopsNewExportsAndCleanupOnlyDeletesThisOwner() async throws {
        try await withStore { store, _ in
            let owner = UUID(), other = UUID(), client = ExportTestClient()
            let repository = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: client, enabled: { true })
            repository.selectOwner(owner)
            try await repository.connect(owner: owner, choices: settings())
            try store.setHealthSettings(settings(), owner: other)
            try store.saveLogs([log(owner: owner), log(owner: other)])
            try await repository.refresh(owner: owner)
            try await repository.disconnect(owner: owner)
            try store.saveLogs([log(owner: owner)])
            #expect(try store.healthExports(owner: owner).count == 4)
            #expect(client.saved.count == 4)
            try await repository.deleteExports(owner: owner)
            #expect(client.saved.isEmpty && client.deleted.count == 4)
            #expect(try store.healthExports(owner: other).allSatisfy(\.pending))
        }
    }
    @Test func switchingOwnerDuringNativeWriteCannotAcknowledgeOldContext() async throws {
        try await withStore { store, _ in
            let owner = UUID(), other = UUID(), client = ExportTestClient()
            let repository = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: client, enabled: { true })
            repository.selectOwner(owner)
            try await repository.connect(owner: owner, choices: settings())
            try store.saveLogs([log(owner: owner)])
            var held: CheckedContinuation<Void, Never>?
            client.onSave = { _ in await withCheckedContinuation { held = $0 } }
            let transfer = Task { try await repository.refresh(owner: owner) }
            while held == nil { await Task.yield() }
            repository.selectOwner(other)
            held?.resume()
            do { try await transfer.value } catch HealthIntegrationError.staleContext {}
            #expect(client.saveCalls == 1)
            #expect(try store.healthExports(owner: owner).allSatisfy(\.pending))
            #expect(try store.healthExports(owner: other).isEmpty)
        }
    }
    @Test func accountClaimPreservesBothExportNamespacesWhenEditing() async throws {
        try await withStore { store, _ in
            let local = UUID(), account = UUID(), localLog = log(owner: UUID()), accountID = UUID()
            try store.setHealthSettings(settings(), owner: local)
            try store.setHealthSettings(settings(), owner: account)
            try store.saveLogs([log(owner: local, id: localLog.id), log(owner: account, id: accountID)])
            let original = try store.healthExports(owner: account)
            try store.claimLocalData(from: local, to: account)
            try store.saveLogs([log(owner: account, id: accountID, calories: 200)])
            let merged = try store.healthExports(owner: account)
            #expect(merged.count == 8)
            #expect(original.allSatisfy { old in merged.contains { $0.id == old.id && $0.revision == 2 } })
            #expect(try store.healthExports(owner: local).isEmpty)
        }
    }
    @Test func viewModelFinishesLoadingBeforeReenablingControlsAndResetsOwner() async throws {
        try await withStore { store, _ in
            let repository = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: ExportTestClient(), enabled: { true })
            let model = HealthIntegrationViewModel(repository: repository)
            model.selectOwner(UUID())
            model.choices.shareNutrition = true
            await model.connect()
            #expect(model.settings.isConnected && model.settings.shareNutrition)
            #expect(!model.isBusy && model.errorMessage == nil)
            await model.disconnect()
            #expect(!model.settings.isConnected && !model.choices.shareNutrition)
            #expect(!model.isBusy)
            model.selectOwner(nil)
            #expect(model.records.isEmpty && model.errorMessage == nil)
        }
    }
    @Test func samplePreservesUnitsPrecisionAndRevision() async throws {
        try await withStore { store, _ in
            let owner = UUID()
            try store.setHealthSettings(settings(), owner: owner)
            try store.saveLogs([log(owner: owner)])
            let record = try #require(store.healthExports(owner: owner).first { $0.kind == .energy })
            let sample = try AppleHealthKitClient.makeSample(record)
            #expect(sample.quantity.doubleValue(for: .kilocalorie()) == 123.25)
            #expect(sample.metadata?[HKMetadataKeySyncIdentifier] as? String == record.id)
            #expect(sample.metadata?[HKMetadataKeySyncVersion] as? Int == record.revision)
        }
    }
}

@MainActor
private final class ExportTestClient: HealthKitClient {
    var isAvailable = true
    var denied: Set<HealthDataKind> = []
    var saved: [String: HealthExportRecord] = [:]
    var deleted: [String] = []
    var saveCalls = 0
    var onSave: ((HealthExportRecord) async -> Void)?
    func requestAccess(settings: HealthIntegrationSettings) async throws {}
    func canWrite(_ kind: HealthDataKind) -> Bool { !denied.contains(kind) }
    func save(_ record: HealthExportRecord) async throws {
        let operation = onSave
        onSave = nil
        await operation?(record)
        saved[record.id] = record
        saveCalls += 1
    }
    func delete(_ record: HealthExportRecord) async throws { saved[record.id] = nil; deleted.append(record.id) }
}

@MainActor
struct HealthExportMigrationTests {
    @Test func versionEightUpgradeKeepsExistingWeightAndAddsEmptyOutbox() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("upgrade.sqlite")
        let owner = UUID()
        do {
            let store = try LocalStore(databaseURL: url)
            try store.saveWeightEntry(WeightEntry(userId: owner, date: Date(), weightKg: 72))
        }
        var database: OpaquePointer?
        #expect(sqlite3_open(url.path, &database) == SQLITE_OK)
        #expect(sqlite3_exec(database, "DROP TABLE health_exports; DROP TABLE health_settings; PRAGMA user_version=8;", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(database)
        let upgraded = try LocalStore(databaseURL: url)
        #expect(upgraded.schemaVersion() == 9)
        #expect(upgraded.getWeightEntries(userId: owner).count == 1)
        #expect(try upgraded.healthExports(owner: owner).isEmpty)
        #expect(try !upgraded.healthSettings(owner: owner).isConnected)
    }
}
