import Foundation

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
}

nonisolated enum HealthIntegrationError: Error {
    case unavailable, denied, invalidSample, staleContext
}

@MainActor
protocol HealthKitClient {
    var isAvailable: Bool { get }
    func requestAccess(settings: HealthIntegrationSettings) async throws
    func canWrite(_ kind: HealthDataKind) -> Bool
    func save(_ record: HealthExportRecord) async throws
    func delete(_ record: HealthExportRecord) async throws
}
