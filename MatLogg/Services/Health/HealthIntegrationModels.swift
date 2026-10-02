import Foundation

/// Local HealthKit routing. These types are deliberately absent from sync-contract v1.
enum HealthDataKind: String, Codable, CaseIterable {
    case energy, protein, carbohydrates, fat, weight
    var unit: String { self == .energy ? "kcal" : self == .weight ? "kg" : "g" }
}

struct HealthIntegrationSettings: Codable, Equatable {
    var shareNutrition = false
    var readWeight = false
    var shareWeight = false
    var connectionID: UUID?
    var exportNamespace = UUID()
    var importStart: Date?
    var lastImport: Date?
    var isConnected: Bool { connectionID != nil }
    func exports(_ kind: HealthDataKind) -> Bool { isConnected && (kind == .weight ? shareWeight : shareNutrition) }
}

enum HealthExportType: String, Codable {
    case upsert = "health.upsert"
    case delete = "health.delete"
}

struct HealthExportRecord: Codable, Identifiable {
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

struct HealthWeightSample: Codable, Identifiable, Equatable {
    var id: UUID
    var timestamp: Date
    var value: Double
    var unit: String
    var source: String
    var isOwnSample: Bool
    var kilograms: Double { unit == "lb" ? value * 0.45359237 : value }
    var isValid: Bool { (unit == "kg" || unit == "lb") && kilograms.isFinite && kilograms > 0 }
}

struct HealthWeightChanges {
    var added: [HealthWeightSample]
    var deleted: [UUID]
    var anchor: Data
}

struct WeightHistoryItem: Identifiable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var source: String
    var manualEntry: WeightEntry?
}

enum HealthIntegrationError: Error {
    case unavailable, denied, invalidSample, staleContext
}

@MainActor
protocol HealthKitClient {
    var isAvailable: Bool { get }
    func requestAccess(settings: HealthIntegrationSettings) async throws
    func canWrite(_ kind: HealthDataKind) -> Bool
    func weightChanges(since: Date, anchor: Data?) async throws -> HealthWeightChanges
    func save(_ record: HealthExportRecord) async throws
    func delete(_ record: HealthExportRecord) async throws
}
