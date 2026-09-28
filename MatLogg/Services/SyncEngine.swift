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

protocol SyncQueueStore {
    func fetchPendingEvents(ownerUserId: UUID, limit: Int) async -> [SyncEvent]
    func markEventsInFlight(_ eventIds: [UUID]) async
    func markEventsAcked(_ eventIds: [UUID]) async
    func markEventForRetry(_ eventId: UUID, error: String?, backoffSeconds: TimeInterval) async
    func markEventDeadLetter(_ eventId: UUID, error: String) async
    func nextPendingRetryDate(ownerUserId: UUID) async -> Date?
}

extension DatabaseService: SyncQueueStore {}

protocol SyncAPIClient {
    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult
}

extension APIService: SyncAPIClient {}

@MainActor
final class SyncEngine {
    static let shared: SyncEngine = {
        let client: any SyncAPIClient
        if let configuration = try? SupabaseConfiguration.load() {
            client = SupabaseService(configuration: configuration)
        } else {
            client = UnavailableSyncAPIClient()
        }
        return SyncEngine(
            databaseService: DatabaseService.shared,
            apiService: client,
            syncEnabled: { FeatureFlags.backendSyncEnabled }
        )
    }()
    
    private let databaseService: any SyncQueueStore
    private let apiService: any SyncAPIClient
    private let syncEnabled: () -> Bool
    private var isSyncing = false
    private var scheduledRetry: Task<Void, Never>?
    private var activeOwnerUserId: UUID?
    private let maximumAutomaticAttempts: Int
    
    init(
        databaseService: any SyncQueueStore,
        apiService: any SyncAPIClient,
        syncEnabled: @escaping () -> Bool,
        maximumAutomaticAttempts: Int = 5
    ) {
        self.databaseService = databaseService
        self.apiService = apiService
        self.syncEnabled = syncEnabled
        self.maximumAutomaticAttempts = max(1, maximumAutomaticAttempts)
    }

    func updateActiveOwner(_ ownerUserId: UUID?) {
        guard activeOwnerUserId != ownerUserId else { return }
        activeOwnerUserId = ownerUserId
        scheduledRetry?.cancel()
        scheduledRetry = nil
    }
    
    func syncPendingEvents(ownerUserId: UUID) async -> SyncResult {
        guard activeOwnerUserId == ownerUserId else {
            return SyncResult(success: false, errorMessage: "Ingen aktiv bruker for synkronisering")
        }
        guard !isSyncing else {
            return SyncResult(success: false, errorMessage: "Synk pågår")
        }
        isSyncing = true
        defer { isSyncing = false }
        
        guard syncEnabled() else {
            return SyncResult(success: false, errorMessage: "Backend ikke aktiv")
        }
        
        while true {
            let pending = await databaseService.fetchPendingEvents(ownerUserId: ownerUserId, limit: 50)
            guard !pending.isEmpty else {
                await scheduleNextRetryIfNeeded(ownerUserId: ownerUserId)
                return SyncResult(success: true, errorMessage: nil)
            }

            let ids = pending.map { $0.eventId }
            await databaseService.markEventsInFlight(ids)

            do {
                guard activeOwnerUserId == ownerUserId else {
                    for event in pending {
                        await databaseService.markEventForRetry(event.eventId, error: nil, backoffSeconds: 0)
                    }
                    return SyncResult(success: false, errorMessage: "Brukeren ble byttet under synkronisering")
                }
                let result = try await apiService.uploadEvents(pending)
                let acked = Set(result.ackedEventIds)
                if !acked.isEmpty {
                    await databaseService.markEventsAcked(Array(acked))
                }

                let rejectedMap = Dictionary(uniqueKeysWithValues: result.rejected.map { ($0.eventId, $0) })
                var failedCount = 0
                let unresolved = pending.filter { !acked.contains($0.eventId) }
                for event in unresolved {
                    if let rejected = rejectedMap[event.eventId] {
                        failedCount += 1
                        await databaseService.markEventDeadLetter(event.eventId, error: rejected.message)
                        continue
                    }
                    let attempt = event.attemptCount + 1
                    if attempt >= maximumAutomaticAttempts {
                        failedCount += 1
                        await databaseService.markEventDeadLetter(event.eventId, error: "Ikke bekreftet av server")
                    } else {
                        let backoff = Backoff.nextDelay(attempt: attempt)
                        await databaseService.markEventForRetry(
                            event.eventId,
                            error: "Ikke bekreftet av server",
                            backoffSeconds: backoff
                        )
                    }
                }

                guard unresolved.isEmpty else {
                    await scheduleNextRetryIfNeeded(ownerUserId: ownerUserId)
                    let message = failedCount > 0
                        ? "\(failedCount) endring(er) krever et nytt manuelt synkforsøk."
                        : "Noen endringer ble ikke bekreftet av serveren og prøves igjen automatisk."
                    return SyncResult(success: false, errorMessage: message)
                }
            } catch {
                let permanent = Self.isPermanentFailure(error)
                let retryAfter = Self.retryAfterSeconds(error)
                var failedCount = 0
                for event in pending {
                    let attempt = event.attemptCount + 1
                    if permanent || attempt >= maximumAutomaticAttempts {
                        failedCount += 1
                        await databaseService.markEventDeadLetter(
                            event.eventId,
                            error: error.localizedDescription
                        )
                    } else {
                        let backoff = retryAfter.map(TimeInterval.init) ?? Backoff.nextDelay(attempt: attempt)
                        await databaseService.markEventForRetry(
                            event.eventId,
                            error: error.localizedDescription,
                            backoffSeconds: backoff
                        )
                    }
                }
                await scheduleNextRetryIfNeeded(ownerUserId: ownerUserId)
                let message = failedCount > 0
                    ? "\(failedCount) endring(er) kunne ikke synkroniseres automatisk. \(error.localizedDescription)"
                    : error.localizedDescription
                return SyncResult(success: false, errorMessage: message)
            }
        }
    }

    private func scheduleNextRetryIfNeeded(ownerUserId: UUID) async {
        scheduledRetry?.cancel()
        scheduledRetry = nil
        guard syncEnabled(),
              let retryDate = await databaseService.nextPendingRetryDate(ownerUserId: ownerUserId) else { return }

        let delay = max(0.1, retryDate.timeIntervalSinceNow)
        scheduledRetry = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.runScheduledRetry(ownerUserId: ownerUserId)
            } catch {}
        }
    }

    private func runScheduledRetry(ownerUserId: UUID) async {
        scheduledRetry = nil
        guard activeOwnerUserId == ownerUserId else { return }
        _ = await syncPendingEvents(ownerUserId: ownerUserId)
    }

    private static func isPermanentFailure(_ error: Error) -> Bool {
        guard case APIService.APIError.backendError(let statusCode, _, _) = error else {
            return false
        }
        return (400...499).contains(statusCode) && statusCode != 408 && statusCode != 429
    }

    private static func retryAfterSeconds(_ error: Error) -> Int? {
        guard case APIService.APIError.rateLimited(let seconds) = error else { return nil }
        return seconds
    }
}

enum Backoff {
    static func nextDelay(attempt: Int) -> TimeInterval {
        let base = min(pow(2.0, Double(attempt - 1)) * 10.0, 6 * 60 * 60)
        let jitter = Double.random(in: 0...5)
        return min(max(base + jitter, 10), 6 * 60 * 60)
    }
}
