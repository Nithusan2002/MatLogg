#if DEBUG && HEALTH_HISTORY_NATIVE_QA
import XCTest
import HealthKit
@testable import MatLogg

/// Explicit physical-device-only build flag; never enabled by regular tests or CI.
@MainActor
final class HealthHistoryDeviceTests: XCTestCase {
    func testNativeHistoryDatesRepeatAndCleanup() async throws {
        let health = HKHealthStore()
        guard HKHealthStore.isHealthDataAvailable() else { throw XCTSkip("Physical HealthKit device required") }
        let kinds: [(HealthDataKind, HKQuantityTypeIdentifier)] = [(.energy, .dietaryEnergyConsumed),
            (.protein, .dietaryProtein), (.carbohydrates, .dietaryCarbohydrates), (.fat, .dietaryFatTotal), (.weight, .bodyMass)]
        let types = try kinds.map { pair -> HKQuantityType in
            try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: pair.1))
        }
        try await health.requestAuthorization(toShare: Set(types), read: Set(types))
        for type in types { XCTAssertEqual(health.authorizationStatus(for: type), .sharingAuthorized) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("native-history-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("test.sqlite"), healthWritesEnabled: true)
        let owner = UUID()
        let calendar = Calendar.current
        let day = try XCTUnwrap(calendar.date(byAdding: .day, value: -3, to: calendar.startOfDay(for: Date())))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let time = try XCTUnwrap(calendar.date(bySettingHour: 12, minute: 34, second: 0, of: day))
        let entry = FoodLog(userId: owner, productId: UUID(), mealType: "lunsj", amountG: 100,
            loggedDate: day, loggedTime: time, calories: 120, proteinG: 4, carbsG: 8, fatG: 3)
        try store.saveLogs([entry])
        let weight = WeightEntry(userId: owner, date: day, weightKg: 72)
        try store.saveWeightEntry(weight)
        var settings = HealthIntegrationSettings()
        settings.shareNutrition = true
        settings.shareWeight = true
        settings.connectionID = UUID()
        try store.setHealthSettings(settings, owner: owner)
        let repo = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: AppleHealthKitClient(), enabled: { true })
        repo.selectOwner(owner)
        let preview = try await repo.previewHistory(owner: owner, request: HealthHistoryRequest(start: day, end: end, nutrition: true, weight: true))
        XCTAssertEqual(preview.foodCount, 1)
        XCTAssertEqual(preview.weightCount, 1)
        do {
            let first = try await repo.shareHistory(owner: owner, preview: preview)
            XCTAssertEqual(first.transferred, 5)
            XCTAssertEqual(first.pending, 0)
            let before = try await ownSamples(health: health, types: types, ids: preview.recordIDs)
            XCTAssertEqual(before.count, 5, "Read permission is required to verify the test samples")
            for sample in before {
                let expected = sample.quantityType.identifier == HKQuantityTypeIdentifier.bodyMass.rawValue ? weight.date : entry.healthExportTimestamp()
                XCTAssertEqual(sample.startDate.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
                let expectedValues: [String: Double] = [HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue: 120,
                    HKQuantityTypeIdentifier.dietaryProtein.rawValue: 4, HKQuantityTypeIdentifier.dietaryCarbohydrates.rawValue: 8,
                    HKQuantityTypeIdentifier.dietaryFatTotal.rawValue: 3, HKQuantityTypeIdentifier.bodyMass.rawValue: 72]
                let expectedValue = try XCTUnwrap(expectedValues[sample.quantityType.identifier])
                let unit: HKUnit = sample.quantityType.identifier == HKQuantityTypeIdentifier.bodyMass.rawValue ? .gramUnit(with: .kilo)
                    : sample.quantityType.identifier == HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue ? .kilocalorie() : .gram()
                XCTAssertEqual(sample.quantity.doubleValue(for: unit), expectedValue, accuracy: 0.001)
            }
            let again = try await repo.previewHistory(owner: owner, request: preview.request)
            XCTAssertEqual(again.unchangedCount, 5)
            let second = try await repo.shareHistory(owner: owner, preview: again)
            XCTAssertEqual(second.transferred, 5)
            XCTAssertEqual(second.pending, 0)
            let after = try await ownSamples(health: health, types: types, ids: preview.recordIDs)
            XCTAssertEqual(after.count, 5)
            XCTAssertEqual(Set(after.map(\.uuid)), Set(before.map(\.uuid)), "Repeated export must retain the same native samples")
        } catch {
            try await repo.deleteExports(owner: owner)
            throw error
        }
        // Owner-scoped cleanup only; no broad Health deletion.
        try await repo.deleteExports(owner: owner)
        let remaining = try await ownSamples(health: health, types: types, ids: preview.recordIDs)
        XCTAssertTrue(remaining.isEmpty)
        // Preserve the disposable outbox for recovery if native cleanup ever fails.
        if remaining.isEmpty { try? FileManager.default.removeItem(at: directory) }
    }

    private func ownSamples(health: HKHealthStore, types: [HKQuantityType], ids: [String]) async throws -> [HKQuantitySample] {
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: ids),
            HKQuery.predicateForObjects(from: HKSource.default())])
        var result: [HKQuantitySample] = []
        for type in types {
            let samples: [HKQuantitySample] = try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume(returning: samples as? [HKQuantitySample] ?? []) }
                }
                health.execute(query)
            }
            result += samples
        }
        return result
    }
}
#endif
