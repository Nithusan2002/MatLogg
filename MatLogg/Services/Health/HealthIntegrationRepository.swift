import Foundation

@MainActor
protocol HealthIntegrationStorage: AnyObject {
    var healthCacheDirectory: URL { get }
    func healthSettings(owner: UUID) throws -> HealthIntegrationSettings
    func setHealthSettings(_ settings: HealthIntegrationSettings, owner: UUID) throws
    func healthExport(id: String, owner: UUID) throws -> HealthExportRecord?
    func healthExports(owner: UUID) throws -> [HealthExportRecord]
    func completeHealthExport(_ record: HealthExportRecord, owner: UUID, at date: Date) throws
    func queueHealthCleanup(owner: UUID) throws
}
extension LocalStore: HealthIntegrationStorage {}

struct HealthIntegrationStatus {
    var settings: HealthIntegrationSettings
    var records: [HealthExportRecord]
    var messages: [HealthDataKind: String]
    var importMessage: String?
}

@MainActor
protocol HealthIntegrationRepository {
    var isAvailable: Bool { get }
    func selectOwner(_ owner: UUID?)
    func status(owner: UUID) throws -> HealthIntegrationStatus
    func connect(owner: UUID, choices: HealthIntegrationSettings) async throws
    func refresh(owner: UUID) async throws
    func disconnect(owner: UUID) throws
    func deleteExports(owner: UUID) async throws
    func importedWeights(owner: UUID) throws -> [HealthWeightSample]
}

@MainActor
final class DefaultHealthIntegrationRepository: HealthIntegrationRepository {
    private let store: (any HealthIntegrationStorage)?
    private let cache: HealthWeightCacheStore
    private let client: any HealthKitClient
    private let enabled: () -> Bool
    private let now: () -> Date
    private var owner: UUID?
    private var contextID = UUID()
    private var clientBusy = false
    private var clientWaiters: [CheckedContinuation<Void, Never>] = []
    private var running: UUID?
    private var messages: [HealthDataKind: String] = [:]
    private var importMessage: String?

    init(store: (any HealthIntegrationStorage)?, cache: HealthWeightCacheStore, client: any HealthKitClient,
         enabled: @escaping () -> Bool = { FeatureFlags.healthIntegrationEnabled }, now: @escaping () -> Date = Date.init) {
        self.store = store
        self.cache = cache
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
        importMessage = nil
    }

    func status(owner: UUID) throws -> HealthIntegrationStatus {
        guard self.owner == owner, let store else { throw HealthIntegrationError.staleContext }
        return HealthIntegrationStatus(settings: try store.healthSettings(owner: owner), records: try store.healthExports(owner: owner),
                                       messages: messages, importMessage: importMessage)
    }

    private func check(owner: UUID, context: UUID, connection: UUID?) throws {
        guard enabled(), self.owner == owner, contextID == context, !Task.isCancelled, let store,
              try store.healthSettings(owner: owner).connectionID == connection else { throw HealthIntegrationError.staleContext }
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
        try check(owner: owner, context: context, connection: connection)
        return try await operation()
    }

    func connect(owner: UUID, choices: HealthIntegrationSettings) async throws {
        guard isAvailable, self.owner == owner, let store else { throw HealthIntegrationError.unavailable }
        let context = contextID
        var settings = try store.healthSettings(owner: owner)
        let previousConnection = settings.connectionID
        let wasReading = settings.readWeight && settings.isConnected
        settings.shareNutrition = choices.shareNutrition
        settings.shareWeight = choices.shareWeight
        settings.readWeight = choices.readWeight
        if !settings.isConnected { settings.connectionID = UUID() }
        if settings.readWeight && !wasReading {
            settings.importStart = Calendar.current.date(byAdding: .day, value: -90, to: now())
            settings.lastImport = nil
        }
        // Authorization completion is not evidence of read permission.
        try await withClientOperation(owner: owner, context: context, connection: previousConnection) {
            try await client.requestAccess(settings: settings)
        }
        try check(owner: owner, context: context, connection: previousConnection)
        if !settings.readWeight || !wasReading { try cache.remove(namespace: settings.exportNamespace) }
        try store.setHealthSettings(settings, owner: owner)
        contextID = UUID() // Invalidate any worker that used the previous choices.
        running = nil
        try await refresh(owner: owner)
    }

    func refresh(owner: UUID) async throws {
        guard isAvailable, self.owner == owner, let store, running == nil else { return }
        let settings = try store.healthSettings(owner: owner)
        guard settings.isConnected else { return }
        let context = contextID
        running = context
        defer { if running == context { running = nil } }
        messages = [:]
        importMessage = nil
        if settings.readWeight, let connection = settings.connectionID, let start = settings.importStart {
            do {
                let snapshot = try cache.read(namespace: settings.exportNamespace, connectionID: connection)
                let changes = try await withClientOperation(owner: owner, context: context, connection: connection) {
                    try await client.weightChanges(since: start, anchor: snapshot.anchor)
                }
                try check(owner: owner, context: context, connection: connection)
                try cache.apply(changes, since: start, namespace: settings.exportNamespace, connectionID: connection)
                var updated = try store.healthSettings(owner: owner)
                updated.lastImport = now()
                try store.setHealthSettings(updated, owner: owner)
                let samples = try cache.read(namespace: settings.exportNamespace, connectionID: connection).samples
                if samples.isEmpty { importMessage = "Ingen tilgjengelige vektmålinger. Kontroller at det finnes data, og at MatLogg har tilgang i Helse." }
            } catch HealthIntegrationError.staleContext { return }
            catch {
                try check(owner: owner, context: context, connection: settings.connectionID)
                importMessage = "Kunne ikke hente vekt fra Helse. Prøv igjen når iPhonen er låst opp."
            }
        }
        try await processExports(owner: owner, context: context, connection: settings.connectionID, cleanupOnly: false)
        try check(owner: owner, context: context, connection: settings.connectionID)
        NotificationCenter.default.post(name: .healthIntegrationDidRefresh, object: owner)
    }

    private func processExports(owner: UUID, context: UUID, connection: UUID?, cleanupOnly: Bool) async throws {
        guard let store else { throw HealthIntegrationError.unavailable }
        // Snapshot the batch; conditional acknowledgement protects edits made while awaiting HealthKit.
        for record in try store.healthExports(owner: owner) where record.pending {
            try check(owner: owner, context: context, connection: connection)
            let currentSettings = try store.healthSettings(owner: owner)
            guard cleanupOnly ? record.isDeletion : currentSettings.exports(record.kind) else { continue }
            guard let latest = try store.healthExport(id: record.id, owner: owner),
                  latest.pending, latest.eventID == record.eventID else { continue }
            do {
                guard client.canWrite(record.kind) else { throw HealthIntegrationError.denied }
                try await withClientOperation(owner: owner, context: context, connection: connection) {
                    if record.isDeletion { try await client.delete(record) }
                    else { try await client.save(record) }
                }
                try check(owner: owner, context: context, connection: connection)
                try store.completeHealthExport(record, owner: owner, at: now())
            } catch HealthIntegrationError.staleContext { return }
            catch {
                try check(owner: owner, context: context, connection: connection)
                messages[record.kind] = "Registreringen er lagret i MatLogg. Overføring til Helse venter. Kontroller tilgangen i Helse."
            }
        }
    }

    func disconnect(owner: UUID) throws {
        guard self.owner == owner, let store else { throw HealthIntegrationError.staleContext }
        contextID = UUID()
        running = nil
        var settings = try store.healthSettings(owner: owner)
        settings.connectionID = nil
        settings.shareNutrition = false
        settings.readWeight = false
        settings.shareWeight = false
        settings.importStart = nil
        settings.lastImport = nil
        // Stop writes before removing cache. A removal error is visible and can be retried.
        try store.setHealthSettings(settings, owner: owner)
        try cache.remove(namespace: settings.exportNamespace)
        messages = [:]
        importMessage = nil
        NotificationCenter.default.post(name: .healthIntegrationDidRefresh, object: owner)
    }

    func deleteExports(owner: UUID) async throws {
        guard isAvailable, self.owner == owner, let store else { throw HealthIntegrationError.unavailable }
        try disconnect(owner: owner)
        try store.queueHealthCleanup(owner: owner)
        let context = contextID
        running = context
        defer { if running == context { running = nil } }
        try await processExports(owner: owner, context: context, connection: nil, cleanupOnly: true)
        try check(owner: owner, context: context, connection: nil)
        if try store.healthExports(owner: owner).contains(where: { $0.pending }) { throw HealthIntegrationError.denied }
    }

    func importedWeights(owner: UUID) throws -> [HealthWeightSample] {
        guard enabled(), self.owner == owner, let store else { return [] }
        let settings = try store.healthSettings(owner: owner)
        guard settings.readWeight, let connection = settings.connectionID else { return [] }
        return try cache.read(namespace: settings.exportNamespace, connectionID: connection).samples
    }
}

extension Notification.Name {
    static let healthDomainDidChange = Notification.Name("MatLogg.healthDomainDidChange")
    static let healthIntegrationDidRefresh = Notification.Name("MatLogg.healthIntegrationDidRefresh")
}

@MainActor
protocol WeightHistoryRepository {
    func history(owner: UUID) async throws -> [WeightHistoryItem]
}

@MainActor
final class DefaultWeightHistoryRepository: WeightHistoryRepository {
    private let manual: any HealthProfileRepository
    private let health: any HealthIntegrationRepository
    init(manual: any HealthProfileRepository, health: any HealthIntegrationRepository) { self.manual = manual; self.health = health }
    func history(owner: UUID) async throws -> [WeightHistoryItem] {
        let entries = await manual.getWeightEntries(userId: owner)
        return Self.merge(manual: entries, imported: try health.importedWeights(owner: owner), calendar: .current)
    }
    static func merge(manual: [WeightEntry], imported: [HealthWeightSample], calendar: Calendar) -> [WeightHistoryItem] {
        var days: [Date: WeightHistoryItem] = [:]
        let ordered = imported.filter { $0.isValid && !$0.isOwnSample }.sorted {
            $0.timestamp == $1.timestamp ? $0.id.uuidString < $1.id.uuidString : $0.timestamp < $1.timestamp
        }
        for sample in ordered {
            let day = calendar.startOfDay(for: sample.timestamp)
            days[day] = WeightHistoryItem(id: sample.id, date: day, weightKg: sample.kilograms,
                                          source: "Fra Helse · \(sample.source)", manualEntry: nil)
        }
        for entry in manual {
            let day = calendar.startOfDay(for: entry.date)
            days[day] = WeightHistoryItem(id: entry.id, date: day, weightKg: entry.weightKg,
                                          source: "Registrert i MatLogg", manualEntry: entry)
        }
        return days.values.sorted { $0.date < $1.date }
    }
}
