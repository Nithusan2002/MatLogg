import Foundation
import HealthKit
import SQLite3
import Testing
@testable import MatLogg

@MainActor
struct HealthIntegrationTests {
    private struct Fixture {
        let directory: URL
        let url: URL
        let store: LocalStore
        let cache: HealthWeightCacheStore
        let client: ControlledHealthClient
        let repository: DefaultHealthIntegrationRepository
        let owner = UUID()
        let now = Date(timeIntervalSince1970: 1_790_899_200)
    }
    private func withFixture(_ body: (Fixture) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("HealthTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.sqlite")
        let store = try LocalStore(databaseURL: url)
        store.healthWritesEnabled = true
        let cache = HealthWeightCacheStore(directory: store.healthCacheDirectory)
        let client = ControlledHealthClient()
        let now = Date(timeIntervalSince1970: 1_790_899_200)
        let repo = DefaultHealthIntegrationRepository(store: store, cache: cache, client: client, enabled: { true }, now: { now })
        let f = Fixture(directory: directory, url: url, store: store, cache: cache, client: client, repository: repo)
        repo.selectOwner(f.owner)
        try await body(f)
    }
    private func connect(_ f: Fixture, nutrition: Bool = true, read: Bool = false, weight: Bool = true) async throws {
        var settings = HealthIntegrationSettings()
        settings.shareNutrition = nutrition
        settings.readWeight = read
        settings.shareWeight = weight
        try await f.repository.connect(owner: f.owner, choices: settings)
    }
    private func log(_ owner: UUID, id: UUID = UUID(), calories: Float = 123.456, time: Date = Date()) -> FoodLog {
        FoodLog(id: id, userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100.25,
                amountUnit: .milliliters, loggedDate: Calendar.current.startOfDay(for: time), loggedTime: time,
                calories: calories, proteinG: 4, carbsG: 12, fatG: 8, nutritionSource: .user)
    }
    private func sample(_ f: Fixture, id: UUID = UUID(), value: Double = 72, seconds: Double = -100, own: Bool = false) -> HealthWeightSample {
        HealthWeightSample(id: id, timestamp: f.now.addingTimeInterval(seconds), value: value,
                           unit: "kg", source: "Synthetic scale", isOwnSample: own)
    }
    private func sql(_ sql: String, url: URL) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }

    @Test func defaultsAndHistoricalLogsAreNotExported() async throws {
        try await withFixture { f in
            let defaults = try f.store.healthSettings(owner: f.owner)
            #expect(!defaults.isConnected && !defaults.shareNutrition && !defaults.readWeight && !defaults.shareWeight)
            let old = log(f.owner, time: f.now.addingTimeInterval(-100_000))
            try f.store.saveLog(old)
            try await connect(f)
            #expect(try f.store.healthExports(owner: f.owner).isEmpty)
            #expect(f.client.backing.saved.isEmpty)
            // Explicit edits after activation export even a historical log.
            try f.store.saveLog(old)
            #expect(try f.store.healthExports(owner: f.owner).count == 4)
        }
    }

    @Test func snapshotsKeepPrecisionSourceUnitAndTimeAndReopen() async throws {
        try await withFixture { f in
            try await connect(f)
            let first = log(f.owner, time: f.now)
            try f.store.saveLog(first)
            let records = try f.store.healthExports(owner: f.owner)
            let energy = try #require(records.first { $0.kind == .energy })
            #expect(energy.value == Double(first.calories))
            #expect(energy.timestamp == first.loggedTime)
            #expect(energy.nutritionSource == .user && energy.amountUnit == "ml" && energy.amount == 100.25)
            let reopened = try LocalStore(databaseURL: f.url)
            #expect(try reopened.healthExports(owner: f.owner).map(\.eventID) == records.map(\.eventID))
            #expect(try reopened.healthSettings(owner: f.owner).connectionID == f.store.healthSettings(owner: f.owner).connectionID)
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
            #expect(try f.store.healthExports(owner: f.owner).allSatisfy { !$0.pending && $0.value == nil && $0.nutritionSource == nil })
        }
    }

    @Test func queueFailureRollsBackDomainAndCanonicalSyncAndCanRetry() async throws {
        try await withFixture { f in
            try await connect(f)
            try sql("CREATE TRIGGER fail_health BEFORE INSERT ON health_exports BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END;", url: f.url)
            #expect(throws: (any Error).self) { try f.store.saveLog(log(f.owner)) }
            #expect(f.store.getAllLogs(userId: f.owner).isEmpty && f.store.pendingSyncCount() == 0)
            #expect(try f.store.healthExports(owner: f.owner).isEmpty)
            try sql("DROP TRIGGER fail_health;", url: f.url)
            try f.store.saveLog(log(f.owner))
            #expect(f.store.pendingSyncCount() == 1)
            #expect(try f.store.healthExports(owner: f.owner).count == 4)
        }
    }

    @Test func deleteFailureRestoresDomainAndBothQueues() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner)
            try f.store.saveLog(item)
            let before = try f.store.healthExports(owner: f.owner).map(\.eventID)
            try sql("CREATE TRIGGER fail_delete BEFORE INSERT ON sync_queue WHEN NEW.type = 'log.delete' BEGIN SELECT RAISE(ABORT, 'synthetic failure'); END;", url: f.url)
            #expect(throws: (any Error).self) { try f.store.deleteLog(item.id) }
            #expect(f.store.getAllLogs(userId: f.owner).count == 1)
            #expect(f.store.pendingSyncCount() == 1)
            #expect(try f.store.healthExports(owner: f.owner).map(\.eventID) == before)
        }
    }

    @Test func editedAndDeletedSamplesAndUndoDoNotDuplicate() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner, time: f.now)
            try f.store.saveLog(item)
            try await f.repository.refresh(owner: f.owner)
            try f.store.saveLog(log(f.owner, id: item.id, calories: 200, time: f.now.addingTimeInterval(-86400)))
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
            let energy = try #require(f.client.backing.saved.values.first { $0.kind == .energy })
            #expect(energy.value == 200 && energy.revision == 2 && energy.timestamp == f.now.addingTimeInterval(-86400))
            try f.store.deleteLog(item.id)
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.isEmpty)
            // Undo uses a fresh log ID, as the existing deletion flow does.
            try f.store.saveLog(log(f.owner, time: f.now))
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
        }
    }

    @Test func ambiguousSuccessRetriesSameRevisionAfterRestart() async throws {
        try await withFixture { f in
            try await connect(f)
            try f.store.saveLog(log(f.owner))
            f.client.failAfterSave = true
            try await f.repository.refresh(owner: f.owner)
            let events = try f.store.healthExports(owner: f.owner)
            #expect(events.allSatisfy { $0.pending })
            let reopened = try LocalStore(databaseURL: f.url)
            let repo = DefaultHealthIntegrationRepository(store: reopened, cache: f.cache, client: f.client, enabled: { true })
            repo.selectOwner(f.owner)
            f.client.failAfterSave = false
            try await repo.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
            #expect(try reopened.healthExports(owner: f.owner).map(\.revision) == events.map(\.revision))
            #expect(try reopened.healthExports(owner: f.owner).allSatisfy { !$0.pending })
        }
    }

    @Test func partialPermissionDoesNotBlockOtherTypesOrLocalLogging() async throws {
        try await withFixture { f in
            try await connect(f)
            f.client.backing.deniedKinds = [.energy]
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            #expect(f.store.getAllLogs(userId: f.owner).count == 1)
            #expect(f.client.backing.saved.count == 3)
            #expect(try f.store.healthExports(owner: f.owner).filter(\.pending).map(\.kind) == [.energy])
            f.client.backing.deniedKinds = []
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
        }
    }

    @Test func weightsReuseDailyIdentityAndDeletionClearsOnlyOwnSample() async throws {
        try await withFixture { f in
            try await connect(f, nutrition: false)
            try f.store.saveWeightEntry(WeightEntry(userId: f.owner, date: f.now, weightKg: 70))
            let first = try #require(f.store.getWeightEntries(userId: f.owner).first)
            try await f.repository.refresh(owner: f.owner)
            try f.store.saveWeightEntry(WeightEntry(userId: f.owner, date: f.now, weightKg: 71))
            #expect(f.store.getWeightEntries(userId: f.owner).first?.id == first.id)
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 1)
            #expect(f.client.backing.saved.values.first?.value == 71)
            try f.store.deleteWeightEntry(first.id)
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.isEmpty)
        }
    }

    @Test func importFiltersHistoryOwnSamplesAndKeepsOutOfServerQueue() async throws {
        try await withFixture { f in
            let included = sample(f)
            f.client.backing.changes = HealthWeightChanges(added: [included, sample(f, seconds: -100 * 86400), sample(f, own: true)], deleted: [], anchor: Data([1]))
            try await connect(f, nutrition: false, read: true, weight: false)
            #expect(try f.repository.importedWeights(owner: f.owner).map(\.id) == [included.id])
            #expect(f.store.getWeightEntries(userId: f.owner).isEmpty && f.store.pendingSyncCount() == 0)
            #expect(f.client.lastSince == Calendar.current.date(byAdding: .day, value: -90, to: f.now))
            f.client.backing.changes = HealthWeightChanges(added: [included], deleted: [included.id], anchor: Data([2]))
            try await f.repository.refresh(owner: f.owner)
            #expect(try f.repository.importedWeights(owner: f.owner).isEmpty)
            #expect(f.client.lastAnchor == Data([1]))
        }
    }

    @Test func atomicCacheDoesNotAdvanceAnchorOnWriteFailureAndIsProtected() async throws {
        try await withFixture { f in
            let namespace = UUID(), connection = UUID()
            try f.cache.apply(HealthWeightChanges(added: [sample(f)], deleted: [], anchor: Data([1])), since: .distantPast, namespace: namespace, connectionID: connection)
            let failing = HealthWeightCacheStore(directory: f.store.healthCacheDirectory, writeFile: { _, _ in throw HealthIntegrationError.unavailable })
            #expect(throws: (any Error).self) {
                try failing.apply(HealthWeightChanges(added: [], deleted: [], anchor: Data([2])), since: .distantPast, namespace: namespace, connectionID: connection)
            }
            #expect(try f.cache.read(namespace: namespace, connectionID: connection).anchor == Data([1]))
            let url = f.store.healthCacheDirectory.appendingPathComponent(namespace.uuidString + ".json")
            #expect(try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
            #if !targetEnvironment(simulator)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            #expect(attributes[.protectionKey] as? String == FileProtectionType.complete.rawValue)
            #endif // Simulator does not expose the iPhone Data Protection class.
        }
    }

    @Test func dailyMergeManualWinsAndConvertsUnitsAndUsesStableTieBreak() async throws {
        try await withFixture { f in
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
            let manual = WeightEntry(userId: f.owner, date: f.now, weightKg: 75)
            let day = calendar.startOfDay(for: manual.date)
            let firstID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001"))
            let lastID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000002"))
            let samples = [HealthWeightSample(id: firstID, timestamp: day, value: 100, unit: "lb", source: "A", isOwnSample: false),
                           HealthWeightSample(id: lastID, timestamp: day, value: 72, unit: "kg", source: "B", isOwnSample: false)]
            let imported = DefaultWeightHistoryRepository.merge(manual: [], imported: samples, calendar: calendar)
            #expect(imported.count == 1 && imported.first?.id == lastID)
            let pounds = DefaultWeightHistoryRepository.merge(manual: [], imported: [samples[0]], calendar: calendar)
            #expect(abs((pounds.first?.weightKg ?? 0) - 45.359237) < 0.000001)
            let merged = DefaultWeightHistoryRepository.merge(manual: [manual], imported: samples, calendar: calendar)
            #expect(merged.count == 1 && merged.first?.manualEntry?.id == manual.id && merged.first?.weightKg == 75)
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: -3600))
            #expect(DefaultWeightHistoryRepository.merge(manual: [], imported: samples, calendar: calendar).first?.date == calendar.startOfDay(for: day))
        }
    }

    @Test func disconnectRemovesImportCancelsJobsRetainsExportsAndNoGapBackfill() async throws {
        try await withFixture { f in
            f.client.backing.changes = HealthWeightChanges(added: [sample(f)], deleted: [], anchor: Data([1]))
            try await connect(f, read: true)
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            try f.store.saveLog(log(f.owner)) // Pending when disconnected.
            let namespace = try f.store.healthSettings(owner: f.owner).exportNamespace
            try f.repository.disconnect(owner: f.owner)
            #expect(try f.repository.importedWeights(owner: f.owner).isEmpty)
            #expect(try f.store.healthExports(owner: f.owner).allSatisfy { !$0.pending && $0.value == nil })
            #expect(!FileManager.default.fileExists(atPath: f.store.healthCacheDirectory.appendingPathComponent(namespace.uuidString + ".json").path))
            #expect(f.client.backing.saved.count == 4)
            try f.store.saveLog(log(f.owner)) // Disabled period.
            try await connect(f)
            #expect(f.client.backing.saved.count == 4)
            #expect(try f.store.healthSettings(owner: f.owner).exportNamespace == namespace)
        }
    }

    @Test func cleanupReportsDeniedDeletionAndCanRetryAfterDisconnect() async throws {
        try await withFixture { f in
            try await connect(f)
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            f.client.backing.deniedKinds = [.energy]
            do { try await f.repository.deleteExports(owner: f.owner); Issue.record("Cleanup should fail") }
            catch {}
            #expect(f.client.backing.saved.count == 1)
            #expect(try !f.store.healthSettings(owner: f.owner).isConnected)
            f.client.backing.deniedKinds = []
            try await f.repository.deleteExports(owner: f.owner)
            #expect(f.client.backing.saved.isEmpty)
        }
    }

    @Test func claimKeepsNamespaceAndCacheWithoutReexportAndDeleteRemovesCache() async throws {
        try await withFixture { f in
            f.client.backing.changes = HealthWeightChanges(added: [sample(f)], deleted: [], anchor: Data([1]))
            try await connect(f, read: true)
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            let before = try f.store.healthExports(owner: f.owner).map(\.id)
            let account = UUID()
            let db = DatabaseService(store: f.store)
            try await db.claimLocalData(from: f.owner, to: f.owner)
            #expect(try f.repository.importedWeights(owner: f.owner).count == 1)
            try await db.claimLocalData(from: f.owner, to: account)
            f.repository.selectOwner(account)
            #expect(try f.repository.importedWeights(owner: account).count == 1)
            #expect(try f.store.healthExports(owner: account).map(\.id) == before)
            #expect(try f.store.healthExports(owner: f.owner).isEmpty)
            try await f.repository.refresh(owner: account)
            #expect(f.client.backing.saved.count == 4)
            let namespace = try f.store.healthSettings(owner: account).exportNamespace
            try await db.deleteLocalData(ownerId: account)
            #expect(try f.store.healthExports(owner: account).isEmpty)
            #expect(!FileManager.default.fileExists(atPath: f.store.healthCacheDirectory.appendingPathComponent(namespace.uuidString + ".json").path))
            #expect(f.client.backing.saved.count == 4) // Explicit Health cleanup is separate.
        }
    }

    @Test func delayedImportCannotCrossProfilesOrRecreateDisconnectedCache() async throws {
        try await withFixture { f in
            try await connect(f, nutrition: false, read: true, weight: false)
            f.client.pauseImport = true
            f.client.backing.changes = HealthWeightChanges(added: [sample(f)], deleted: [], anchor: Data([9]))
            let task = Task { try await f.repository.refresh(owner: f.owner) }
            for _ in 0..<1000 where f.client.importContinuation == nil { await Task.yield() }
            let continuation = try #require(f.client.importContinuation)
            let other = UUID()
            f.repository.selectOwner(other)
            continuation.resume()
            try await task.value
            #expect(try f.repository.importedWeights(owner: other).isEmpty)
            #expect(try !f.store.healthSettings(owner: other).isConnected)
        }
    }

    @Test func newerEditWhileSaveInFlightIsNotAcknowledgedAndRetryUsesLatest() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner)
            try f.store.saveLog(item)
            f.client.pauseSave = true
            let task = Task { try await f.repository.refresh(owner: f.owner) }
            for _ in 0..<1000 where f.client.saveContinuation == nil { await Task.yield() }
            let continuation = try #require(f.client.saveContinuation)
            try f.store.saveLog(log(f.owner, id: item.id, calories: 222))
            f.client.pauseSave = false
            continuation.resume()
            try await task.value
            #expect(try f.store.healthExports(owner: f.owner).allSatisfy { $0.pending && $0.revision == 2 })
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
            #expect(f.client.backing.saved.values.first { $0.kind == .energy }?.value == 222)
        }
    }

    @Test func disabledFeatureNeverReadsWritesOrRequestsAccess() async throws {
        try await withFixture { f in
            try await connect(f)
            try f.store.saveLog(log(f.owner))
            let repo = DefaultHealthIntegrationRepository(store: f.store, cache: f.cache, client: f.client, enabled: { false })
            repo.selectOwner(f.owner)
            try await repo.refresh(owner: f.owner)
            #expect(f.client.backing.saved.isEmpty && !repo.isAvailable)
            #expect(try repo.importedWeights(owner: f.owner).isEmpty)
            f.store.healthWritesEnabled = false
            let before = try f.store.healthExports(owner: f.owner).count
            try f.store.saveLog(log(f.owner))
            #expect(try f.store.healthExports(owner: f.owner).count == before)
        }
    }

    @Test func importFailureKeepsPreviousAnchorAndDoesNotBlockExports() async throws {
        try await withFixture { f in
            f.client.backing.changes = HealthWeightChanges(added: [sample(f)], deleted: [], anchor: Data([1]))
            try await connect(f, read: true)
            f.client.failImport = true
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.backing.saved.count == 4)
            #expect(try f.repository.importedWeights(owner: f.owner).count == 1)
            #expect(try f.repository.status(owner: f.owner).importMessage != nil)
            f.client.failImport = false
            f.client.backing.changes = HealthWeightChanges(added: [], deleted: [], anchor: Data([2]))
            try await f.repository.refresh(owner: f.owner)
            #expect(f.client.lastAnchor == Data([1]))
        }
    }

    @Test func delayedConnectionCannotEnableAnotherProfile() async throws {
        try await withFixture { f in
            let vm = HealthIntegrationViewModel(repository: f.repository)
            vm.selectOwner(f.owner)
            vm.choices.shareNutrition = true
            f.client.pauseRequest = true
            let task = Task { await vm.connect() }
            for _ in 0..<1000 where f.client.requestContinuation == nil { await Task.yield() }
            let continuation = try #require(f.client.requestContinuation)
            let other = UUID()
            vm.selectOwner(other)
            continuation.resume()
            await task.value
            #expect(!vm.settings.isConnected && !vm.isBusy && vm.errorMessage == nil)
            #expect(try !f.store.healthSettings(owner: f.owner).isConnected)
            #expect(try !f.store.healthSettings(owner: other).isConnected)
        }
    }

    @Test func lateDeletionIsSerializedBeforeNewerWriteEvenAcrossContextChanges() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner)
            try f.store.saveLog(item)
            try await f.repository.refresh(owner: f.owner)
            try f.store.deleteLog(item.id)
            f.client.pauseDelete = true
            let old = Task { try await f.repository.refresh(owner: f.owner) }
            for _ in 0..<1000 where f.client.deleteContinuation == nil { await Task.yield() }
            let continuation = try #require(f.client.deleteContinuation)
            f.repository.selectOwner(UUID())
            f.repository.selectOwner(f.owner)
            try f.store.saveLog(log(f.owner, id: item.id, calories: 333))
            let next = Task { try await f.repository.refresh(owner: f.owner) }
            // A new worker is allowed, but native work must wait behind the old deletion.
            for _ in 0..<20 { await Task.yield() }
            #expect(f.client.backing.saved.values.first { $0.kind == .energy }?.value == Double(item.calories))
            f.client.pauseDelete = false
            continuation.resume()
            _ = try? await old.value
            try await next.value
            #expect(f.client.backing.saved.count == 4)
            #expect(f.client.backing.saved.values.first { $0.kind == .energy }?.value == 333)
            #expect(try f.store.healthExports(owner: f.owner).allSatisfy { !$0.pending })
        }
    }

    @Test func ownershipAndUnknownLegacyProvenanceArePreserved() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner)
            try f.store.saveLog(item)
            #expect(throws: (any Error).self) { try f.store.saveLog(log(UUID(), id: item.id)) }
            let weight = WeightEntry(userId: f.owner, date: f.now, weightKg: 70)
            try f.store.saveWeightEntry(weight)
            #expect(throws: (any Error).self) { try f.store.saveWeightEntry(WeightEntry(id: weight.id, userId: UUID(), date: f.now, weightKg: 80)) }
            var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
            json.removeValue(forKey: "nutritionSource")
            let legacy = try JSONDecoder().decode(FoodLog.self, from: JSONSerialization.data(withJSONObject: json))
            #expect(legacy.nutritionSource == nil)
            try f.store.saveLog(legacy)
            #expect(try f.store.healthExports(owner: f.owner).filter { $0.kind != .weight }.allSatisfy { $0.nutritionSource == nil })
        }
    }

    @Test func duplicateConnectPreservesImportStartAndDoesNotBackfillOrDuplicate() async throws {
        try await withFixture { f in
            try await connect(f, read: true)
            let first = try f.store.healthSettings(owner: f.owner)
            try f.store.saveLog(log(f.owner))
            try await f.repository.refresh(owner: f.owner)
            try await connect(f, read: true)
            let second = try f.store.healthSettings(owner: f.owner)
            #expect(first.connectionID == second.connectionID && first.importStart == second.importStart)
            #expect(f.client.backing.saved.count == 4)
            #expect(f.client.backing.requests.count == 2)
            #expect(f.client.backing.requests.allSatisfy { $0.shareNutrition && $0.readWeight && $0.shareWeight })
        }
    }

    @Test func nativeSampleConversionUsesSDKTypesUnitsMetadataAndExactTimestamp() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner, time: f.now)
            try f.store.saveLog(item)
            try f.store.saveWeightEntry(WeightEntry(userId: f.owner, date: f.now, weightKg: 72.125))
            let records = try f.store.healthExports(owner: f.owner)
            #expect(records.count == 5)
            #expect(records.allSatisfy { $0.type == .upsert && $0.schemaVersion == 1 })
            for record in records {
                let sample = try AppleHealthKitClient.makeSample(record)
                let unit = record.kind == .energy ? HKUnit.kilocalorie() : record.kind == .weight ? .gramUnit(with: .kilo) : .gram()
                #expect(sample.quantity.doubleValue(for: unit) == record.value)
                #expect(sample.startDate == record.timestamp && sample.endDate == record.timestamp)
                #expect(sample.metadata?[HKMetadataKeySyncIdentifier] as? String == record.id)
                #expect(sample.metadata?[HKMetadataKeySyncVersion] as? Int == record.revision)
                if record.kind == .energy { #expect(sample.quantityType.identifier == HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue) }
                if record.kind == .weight { #expect(sample.quantityType.identifier == HKQuantityTypeIdentifier.bodyMass.rawValue) }
            }
        }
    }

    @Test func dayCopyExportsOnSelectedDayWithOriginalSource() async throws {
        try await withFixture { f in
            try await connect(f)
            let item = log(f.owner, time: f.now)
            try f.store.saveLog(item)
            let target = try #require(Calendar.current.date(byAdding: .day, value: 1, to: f.now))
            let vm = LogViewModel(repository: DatabaseService(store: f.store))
            #expect(await vm.copyLogs(from: f.now, to: target, userId: f.owner))
            let copy = try #require(f.store.getAllLogs(userId: f.owner).first { $0.id != item.id })
            #expect(Calendar.current.isDate(copy.loggedTime, inSameDayAs: target))
            #expect(copy.nutritionSource == item.nutritionSource)
            let exports = try f.store.healthExports(owner: f.owner).filter { $0.id.contains(copy.id.uuidString) }
            #expect(exports.count == 4 && exports.allSatisfy { $0.timestamp == copy.loggedTime })
        }
    }

    @Test func viewModelDisconnectResetsPersistedAndDraftChoices() async throws {
        try await withFixture { f in
            let vm = HealthIntegrationViewModel(repository: f.repository)
            vm.selectOwner(f.owner)
            vm.choices.shareNutrition = true
            vm.choices.readWeight = true
            await vm.connect()
            #expect(vm.settings.isConnected && vm.choices.shareNutrition && vm.choices.readWeight)
            vm.disconnect()
            #expect(!vm.settings.isConnected && !vm.choices.shareNutrition && !vm.choices.readWeight && vm.errorMessage == nil)
        }
    }

    @Test func migrationFromSevenPreservesDataAndSyncEvents() async throws {
        try await withFixture { f in
            let item = log(f.owner)
            try f.store.saveLog(item)
            try sql("DROP TABLE health_exports; DROP TABLE health_settings; PRAGMA user_version = 7;", url: f.url)
            let migrated = try LocalStore(databaseURL: f.url)
            #expect(migrated.schemaVersion() == 8)
            #expect(migrated.getAllLogs(userId: f.owner).map(\.id) == [item.id])
            #expect(migrated.fetchPendingEvents(limit: 10).count == 1)
            #expect(try migrated.healthExports(owner: f.owner).isEmpty)
        }
    }
}

@MainActor
private final class ControlledHealthClient: HealthKitClient {
    let backing = FakeHealthKitClient()
    var isAvailable: Bool { backing.isAvailable }
    var failAfterSave = false
    var pauseSave = false
    var pauseImport = false
    var failImport = false
    var pauseRequest = false
    var pauseDelete = false
    var requestContinuation: CheckedContinuation<Void, Never>?
    var deleteContinuation: CheckedContinuation<Void, Never>?
    var saveContinuation: CheckedContinuation<Void, Never>?
    var importContinuation: CheckedContinuation<Void, Never>?
    var lastSince: Date?
    var lastAnchor: Data?
    func requestAccess(settings: HealthIntegrationSettings) async throws {
        if pauseRequest { await withCheckedContinuation { requestContinuation = $0 } }
        try await backing.requestAccess(settings: settings)
    }
    func canWrite(_ kind: HealthDataKind) -> Bool { backing.canWrite(kind) }
    func weightChanges(since: Date, anchor: Data?) async throws -> HealthWeightChanges {
        lastSince = since; lastAnchor = anchor
        if failImport { throw HealthIntegrationError.unavailable }
        if pauseImport { await withCheckedContinuation { importContinuation = $0 } }
        return try await backing.weightChanges(since: since, anchor: anchor)
    }
    func save(_ record: HealthExportRecord) async throws {
        if pauseSave { await withCheckedContinuation { saveContinuation = $0 } }
        try await backing.save(record)
        if failAfterSave { throw HealthIntegrationError.unavailable }
    }
    func delete(_ record: HealthExportRecord) async throws {
        if pauseDelete { await withCheckedContinuation { deleteContinuation = $0 } }
        try await backing.delete(record)
    }
}
