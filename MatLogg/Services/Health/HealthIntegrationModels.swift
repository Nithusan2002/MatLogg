import Foundation
import CryptoKit

/// Local HealthKit routing. These types are deliberately absent from sync-contract v1.
nonisolated enum HealthDataKind: String, Codable, CaseIterable, Sendable {
    case energy, protein, carbohydrates, fat, weight
    var unit: String { self == .energy ? "kcal" : self == .weight ? "kg" : "g" }
}

nonisolated struct HealthIntegrationSettings: Codable, Equatable, Sendable {
    var shareNutrition = false
    var shareWeight = false
    var connectionID: UUID?
    var exportNamespace = UUID()
    var isConnected: Bool { connectionID != nil }
    func exports(_ kind: HealthDataKind) -> Bool { isConnected && (kind == .weight ? shareWeight : shareNutrition) }
}

nonisolated enum HealthExportType: String, Codable, Sendable {
    case upsert = "health.upsert"
    case delete = "health.delete"
}

nonisolated struct HealthExportRecord: Codable, Identifiable, Sendable {
    var id: String // Stable HKMetadataKeySyncIdentifier; independent of profile claims.
    var kind: HealthDataKind
    var revision: Int
    var eventID: UUID
    var schemaVersion = 1
    var pending: Bool
    var type: HealthExportType
    var isDeletion: Bool {
        get { type == .delete }
        set { type = newValue ? .delete : .upsert }
    }
    var value: Double?
    var timestamp: Date?
    var nutritionSource: NutritionSource?
    var amount: Float?
    var amountUnit: String?
    var lastSuccess: Date?
    var fingerprint: String? = nil
}

nonisolated enum HealthIntegrationError: Error {
    case unavailable, denied, invalidSample, staleContext, historyChanged
}

@MainActor
protocol HealthKitClient {
    var isAvailable: Bool { get }
    func requestAccess(settings: HealthIntegrationSettings) async throws
    func canWrite(_ kind: HealthDataKind) -> Bool
    func save(_ record: HealthExportRecord) async throws
    func delete(_ record: HealthExportRecord) async throws
}

nonisolated struct HealthHistoryRequest: Equatable, Sendable {
    let start: Date
    let end: Date // Exclusive start of the day after the final selected day.
    let nutrition: Bool
    let weight: Bool
    var isValid: Bool { start.timeIntervalSince1970.isFinite && end.timeIntervalSince1970.isFinite && start < end && (nutrition || weight) }
}

nonisolated struct HealthHistoryPreview: Equatable, Sendable {
    let request: HealthHistoryRequest
    let signature: String
    let foodCount: Int
    let weightCount: Int
    let sampleCount: Int
    let unchangedCount: Int
    let recordIDs: [String]
    var registrationSummary: String {
        "\(foodCount) \(foodCount == 1 ? "matregistrering" : "matregistreringer") og \(weightCount) \(weightCount == 1 ? "vektregistrering" : "vektregistreringer")"
    }
}

nonisolated struct HealthHistoryResult: Sendable {
    let transferred: Int
    let pending: Int
}

nonisolated func healthFingerprint(_ values: [String]) -> String {
    // Length prefixes avoid ambiguity without retaining another nutrition snapshot.
    let text = values.map { "\($0.utf8.count):\($0)" }.joined()
    return SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
}
