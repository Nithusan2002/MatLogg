import Foundation

nonisolated protocol HealthIntegrationStorage: Sendable {
    func healthSettings(owner: UUID) async throws -> HealthIntegrationSettings
    func setHealthSettings(_ settings: HealthIntegrationSettings, owner: UUID) async throws
    func healthExport(id: String, owner: UUID) async throws -> HealthExportRecord?
    func healthExports(owner: UUID) async throws -> [HealthExportRecord]
    func completeHealthExport(_ record: HealthExportRecord, owner: UUID, at date: Date) async throws
    func queueHealthCleanup(owner: UUID) async throws
}

/// SQLite work runs on this actor, never on the UI actor.
actor LocalHealthExportStorage: HealthIntegrationStorage {
    private let store: LocalStore
    init(store: LocalStore) { self.store = store }
    func healthSettings(owner: UUID) throws -> HealthIntegrationSettings { try store.healthSettings(owner: owner) }
    func setHealthSettings(_ settings: HealthIntegrationSettings, owner: UUID) throws { try store.setHealthSettings(settings, owner: owner) }
    func healthExport(id: String, owner: UUID) throws -> HealthExportRecord? { try store.healthExport(id: id, owner: owner) }
    func healthExports(owner: UUID) throws -> [HealthExportRecord] { try store.healthExports(owner: owner) }
    func completeHealthExport(_ record: HealthExportRecord, owner: UUID, at date: Date) throws { try store.completeHealthExport(record, owner: owner, at: date) }
    func queueHealthCleanup(owner: UUID) throws { try store.queueHealthCleanup(owner: owner) }
}

struct HealthIntegrationStatus {
    var settings: HealthIntegrationSettings
    var records: [HealthExportRecord]
    var messages: [HealthDataKind: String]
}

@MainActor
protocol HealthIntegrationRepository {
    var isAvailable: Bool { get }
    func selectOwner(_ owner: UUID?)
    func status(owner: UUID) async throws -> HealthIntegrationStatus
    func connect(owner: UUID, choices: HealthIntegrationSettings) async throws
    func refresh(owner: UUID) async throws
    func disconnect(owner: UUID) async throws
    func deleteExports(owner: UUID) async throws
}

@MainActor
final class DefaultHealthIntegrationRepository: HealthIntegrationRepository {
    private let store: (any HealthIntegrationStorage)?
    private let client: any HealthKitClient
    private let enabled: () -> Bool
    private let now: () -> Date
    private var owner: UUID?
    private var contextID = UUID()
    private var clientBusy = false
    private var clientWaiters: [CheckedContinuation<Void, Never>] = []
    private var running: UUID?
    private var messages: [HealthDataKind: String] = [:]

    init(store: (any HealthIntegrationStorage)?, client: any HealthKitClient,
         enabled: @escaping () -> Bool = { FeatureFlags.healthIntegrationEnabled }, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.client = client
        self.enabled = enabled
        self.now = now
    }
    var isAvailable: Bool { enabled() && store != nil && client.isAvailable }

    func selectOwner(_ owner: UUID?) {
        guard self.owner != owner else { return }
        self.owner = owner
        contextID = UUID()
        running = nil
        messages = [:]
    }

    func status(owner: UUID) async throws -> HealthIntegrationStatus {
        guard self.owner == owner, let store else { throw HealthIntegrationError.staleContext }
        return HealthIntegrationStatus(settings: try await store.healthSettings(owner: owner), records: try await store.healthExports(owner: owner),
                                       messages: messages)
    }

    private func check(owner: UUID, context: UUID, connection: UUID?) async throws {
        guard enabled(), self.owner == owner, contextID == context, !Task.isCancelled, let store else { throw HealthIntegrationError.staleContext }
        let settings = try await store.healthSettings(owner: owner)
        guard self.owner == owner, contextID == context, !Task.isCancelled,
              settings.connectionID == connection else { throw HealthIntegrationError.staleContext }
    }

    // Serialize native calls across connection/profile changes, including old in-flight deletions.
    private func withClientOperation<T>(owner: UUID, context: UUID, connection: UUID?,
                                        _ operation: () async throws -> T) async throws -> T {
        if clientBusy {
            await withCheckedContinuation { clientWaiters.append($0) }
        } else { clientBusy = true }
        defer {
            if clientWaiters.isEmpty { clientBusy = false }
            else { clientWaiters.removeFirst().resume() }
        }
        try await check(owner: owner, context: context, connection: connection)
        return try await operation()
    }

    func connect(owner: UUID, choices: HealthIntegrationSettings) async throws {
        guard isAvailable, self.owner == owner, let store else { throw HealthIntegrationError.unavailable }
        let context = contextID
        var settings = try await store.healthSettings(owner: owner)
        let previousConnection = settings.connectionID
        settings.shareNutrition = choices.shareNutrition
        settings.shareWeight = choices.shareWeight
        if !settings.isConnected { settings.connectionID = UUID() }

        // Completion is not evidence that every selected write permission was granted.
        try await withClientOperation(owner: owner, context: context, connection: previousConnection) {
            try await client.requestAccess(settings: settings)
        }
        try await check(owner: owner, context: context, connection: previousConnection)
        try await store.setHealthSettings(settings, owner: owner)
        guard self.owner == owner, contextID == context else { throw HealthIntegrationError.staleContext }
        contextID = UUID() // Invalidate any worker that used the previous choices.
        running = nil
        try await refresh(owner: owner)
    }

    func refresh(owner: UUID) async throws {
        guard isAvailable, self.owner == owner, let store, running == nil else { return }
        let requestedContext = contextID
        let settings = try await store.healthSettings(owner: owner)
        guard self.owner == owner, contextID == requestedContext, running == nil else { return }
        guard settings.isConnected else { return }
        let context = contextID
        running = context
        defer { if running == context { running = nil } }
        messages = [:]
        try await processExports(owner: owner, context: context, connection: settings.connectionID, cleanupOnly: false)
        try await check(owner: owner, context: context, connection: settings.connectionID)
    }

    private func processExports(owner: UUID, context: UUID, connection: UUID?, cleanupOnly: Bool) async throws {
        guard let store else { throw HealthIntegrationError.unavailable }
        // Snapshot the batch; conditional acknowledgement protects edits made while awaiting HealthKit.
        for record in try await store.healthExports(owner: owner) where record.pending {
            try await check(owner: owner, context: context, connection: connection)
            let currentSettings = try await store.healthSettings(owner: owner)
            guard cleanupOnly ? record.isDeletion : currentSettings.exports(record.kind) else { continue }
            guard let latest = try await store.healthExport(id: record.id, owner: owner),
                  latest.pending, latest.eventID == record.eventID else { continue }
            do {
                guard client.canWrite(record.kind) else { throw HealthIntegrationError.denied }
                try await withClientOperation(owner: owner, context: context, connection: connection) {
                    if record.isDeletion { try await client.delete(record) }
                    else { try await client.save(record) }
                }
                try await check(owner: owner, context: context, connection: connection)
                try await store.completeHealthExport(record, owner: owner, at: now())
            } catch HealthIntegrationError.staleContext { return }
            catch {
                try await check(owner: owner, context: context, connection: connection)
                messages[record.kind] = "Lagret i Spor Mat. Overføring venter. Sjekk tilgangen i Helse."
            }
        }
    }

    func disconnect(owner: UUID) async throws {
        guard self.owner == owner, let store else { throw HealthIntegrationError.staleContext }
        contextID = UUID()
        running = nil
        let context = contextID
        var settings = try await store.healthSettings(owner: owner)
        guard self.owner == owner, contextID == context else { throw HealthIntegrationError.staleContext }
        settings.connectionID = nil
        settings.shareNutrition = false
        settings.shareWeight = false
        // Persist opt-out before any subsequent native operation.
        try await store.setHealthSettings(settings, owner: owner)
        guard self.owner == owner, contextID == context else { throw HealthIntegrationError.staleContext }
        messages = [:]
    }

    func deleteExports(owner: UUID) async throws {
        guard isAvailable, self.owner == owner, let store else { throw HealthIntegrationError.unavailable }
        try await disconnect(owner: owner)
        try await store.queueHealthCleanup(owner: owner)
        let context = contextID
        running = context
        defer { if running == context { running = nil } }
        try await processExports(owner: owner, context: context, connection: nil, cleanupOnly: true)
        try await check(owner: owner, context: context, connection: nil)
        if try await store.healthExports(owner: owner).contains(where: { $0.pending }) { throw HealthIntegrationError.denied }
    }

}

extension Notification.Name {
    nonisolated static let healthDomainDidChange = Notification.Name("MatLogg.healthDomainDidChange")
}
