import Foundation
import HealthKit

@MainActor
final class AppleHealthKitClient: HealthKitClient {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static func type(_ kind: HealthDataKind) throws -> HKQuantityType {
        let identifier: HKQuantityTypeIdentifier
        switch kind {
        case .energy: identifier = .dietaryEnergyConsumed
        case .protein: identifier = .dietaryProtein
        case .carbohydrates: identifier = .dietaryCarbohydrates
        case .fat: identifier = .dietaryFatTotal
        case .weight: identifier = .bodyMass
        }
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { throw HealthIntegrationError.unavailable }
        return type
    }

    func requestAccess(settings: HealthIntegrationSettings) async throws {
        guard isAvailable else { throw HealthIntegrationError.unavailable }
        let write = try Set(HealthDataKind.allCases.filter { settings.exports($0) }.map { try Self.type($0) as HKSampleType })
        let read: Set<HKObjectType> = settings.readWeight ? [try Self.type(.weight)] : []
        try await store.requestAuthorization(toShare: write, read: read)
    }

    func canWrite(_ kind: HealthDataKind) -> Bool {
        guard let type = try? Self.type(kind) else { return false }
        return store.authorizationStatus(for: type) == .sharingAuthorized
    }

    func weightChanges(since: Date, anchor: Data?) async throws -> HealthWeightChanges {
        let type = try Self.type(.weight)
        let decoded = try anchor.map { try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: type, predicate: predicate, anchor: decoded ?? nil, limit: HKObjectQueryNoLimit) { _, samples, deleted, next, error in
                if let error { continuation.resume(throwing: error); return }
                guard let next else { continuation.resume(throwing: HealthIntegrationError.invalidSample); return }
                do {
                    let weights = (samples ?? []).compactMap { sample -> HealthWeightSample? in
                        guard let sample = sample as? HKQuantitySample else { return nil }
                        return HealthWeightSample(id: sample.uuid, timestamp: sample.startDate,
                                                  value: sample.quantity.doubleValue(for: .gramUnit(with: .kilo)), unit: "kg",
                                                  source: sample.sourceRevision.source.name,
                                                  isOwnSample: sample.sourceRevision.source.bundleIdentifier == Bundle.main.bundleIdentifier)
                    }
                    let data = try NSKeyedArchiver.archivedData(withRootObject: next, requiringSecureCoding: true)
                    continuation.resume(returning: HealthWeightChanges(added: weights, deleted: (deleted ?? []).map(\.uuid), anchor: data))
                } catch { continuation.resume(throwing: error) }
            }
            store.execute(query)
        }
    }

    func save(_ record: HealthExportRecord) async throws {
        guard canWrite(record.kind) else { throw HealthIntegrationError.denied }
        try await store.save(Self.makeSample(record))
    }

    /// Pure conversion, testable without constructing or opening HKHealthStore.
    static func makeSample(_ record: HealthExportRecord) throws -> HKQuantitySample {
        guard let value = record.value, value.isFinite, value >= 0, let date = record.timestamp,
              date.timeIntervalSince1970.isFinite else { throw HealthIntegrationError.invalidSample }
        let unit = record.kind == .energy ? HKUnit.kilocalorie() : record.kind == .weight ? .gramUnit(with: .kilo) : .gram()
        var metadata: [String: Any] = [HKMetadataKeySyncIdentifier: record.id, HKMetadataKeySyncVersion: record.revision]
        if let source = record.nutritionSource { metadata["MatLoggNutritionSource"] = source.rawValue }
        if let amount = record.amount { metadata["MatLoggAmount"] = Double(amount) }
        if let amountUnit = record.amountUnit { metadata["MatLoggAmountUnit"] = amountUnit }
        return HKQuantitySample(type: try Self.type(record.kind), quantity: HKQuantity(unit: unit, doubleValue: value),
                                start: date, end: date, metadata: metadata)
    }

    func delete(_ record: HealthExportRecord) async throws {
        guard canWrite(record.kind) else { throw HealthIntegrationError.denied }
        let identifier = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeySyncIdentifier, allowedValues: [record.id])
        let ownSource = HKQuery.predicateForObjects(from: HKSource.default())
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [identifier, ownSource])
        let type = try Self.type(record.kind)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.deleteObjects(of: type, predicate: predicate) { success, _, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume() }
                else { continuation.resume(throwing: HealthIntegrationError.denied) }
            }
        }
    }
}

/// Used by demo/developer sessions and UI tests. Never opens HKHealthStore.
@MainActor
final class FakeHealthKitClient: HealthKitClient {
    var isAvailable = true
    var deniedKinds: Set<HealthDataKind> = []
    var changes = HealthWeightChanges(added: [], deleted: [], anchor: Data())
    private(set) var saved: [String: HealthExportRecord] = [:]
    private(set) var requests: [HealthIntegrationSettings] = []
    func requestAccess(settings: HealthIntegrationSettings) async throws { requests.append(settings) }
    func canWrite(_ kind: HealthDataKind) -> Bool { !deniedKinds.contains(kind) }
    func weightChanges(since: Date, anchor: Data?) async throws -> HealthWeightChanges { changes }
    func save(_ record: HealthExportRecord) async throws {
        guard canWrite(record.kind) else { throw HealthIntegrationError.denied }
        if (saved[record.id]?.revision ?? 0) < record.revision { saved[record.id] = record }
    }
    func delete(_ record: HealthExportRecord) async throws {
        guard canWrite(record.kind) else { throw HealthIntegrationError.denied }
        saved.removeValue(forKey: record.id)
    }
}
