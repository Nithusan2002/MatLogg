import Foundation

enum SyncReason {
    case userInitiated
    case appLaunch
    case foreground
    case networkRestored
}

struct SyncResult {
    let success: Bool
    let errorMessage: String?
}

final class SyncEngine {
    static let shared = SyncEngine()
    
    private let databaseService = DatabaseService.shared
    private let apiService = APIService()
    private var isSyncing = false
    
    private init() {}
    
    func triggerSync(reason: SyncReason) {
        Task { _ = await syncPendingEvents() }
    }
    
    func syncPendingEvents() async -> SyncResult {
        guard !isSyncing else {
            return SyncResult(success: false, errorMessage: "Synk pågår")
        }
        isSyncing = true
        defer { isSyncing = false }
        
        guard FeatureFlags.backendSyncEnabled else {
            return SyncResult(success: false, errorMessage: "Backend ikke aktiv")
        }
        
        let pending = await databaseService.fetchPendingEvents(limit: 50)
        guard !pending.isEmpty else {
            return SyncResult(success: true, errorMessage: nil)
        }
        
        let ids = pending.map { $0.eventId }
        await databaseService.markEventsInFlight(ids)
        
        do {
            let result = try await apiService.uploadEvents(pending)
            let acked = Set(result.ackedEventIds)
            if !acked.isEmpty {
                await databaseService.markEventsAcked(Array(acked))
            }
            
            let rejectedMap = Dictionary(uniqueKeysWithValues: result.rejected.map { ($0.eventId, $0) })
            let toRetry = pending.filter { !acked.contains($0.eventId) }
            for event in toRetry {
                let attempt = event.attemptCount + 1
                let backoff = Backoff.nextDelay(attempt: attempt)
                let error = rejectedMap[event.eventId]?.message ?? "Ikke bekreftet av server"
                await databaseService.markEventForRetry(event.eventId, error: error, backoffSeconds: backoff)
            }
            
            return SyncResult(success: true, errorMessage: nil)
        } catch {
            for event in pending {
                let attempt = event.attemptCount + 1
                let backoff = Backoff.nextDelay(attempt: attempt)
                await databaseService.markEventForRetry(event.eventId, error: error.localizedDescription, backoffSeconds: backoff)
            }
            return SyncResult(success: false, errorMessage: error.localizedDescription)
        }
    }
}

enum Backoff {
    static func nextDelay(attempt: Int) -> TimeInterval {
        let base = min(pow(2.0, Double(attempt - 1)) * 10.0, 6 * 60 * 60)
        let jitter = Double.random(in: 0...5)
        return min(max(base + jitter, 10), 6 * 60 * 60)
    }
}
