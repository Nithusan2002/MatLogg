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
        let read: Set<HKObjectType> = []
        try await store.requestAuthorization(toShare: write, read: read)
    }

    func canWrite(_ kind: HealthDataKind) -> Bool {
        guard let type = try? Self.type(kind) else { return false }
        return store.authorizationStatus(for: type) == .sharingAuthorized
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
