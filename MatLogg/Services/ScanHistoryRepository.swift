import Foundation

nonisolated struct ScanHistorySnapshot: Sendable {
    let scans: [ScanHistory]
    let products: [UUID: Product]
}

protocol ScanHistoryRepository {
    func loadScanHistory(userId: UUID) async throws -> ScanHistorySnapshot
}

extension DatabaseService: ScanHistoryRepository {}
