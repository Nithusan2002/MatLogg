import Foundation

/// Disposable, protected local cache. Import data and anchor commit in one atomic file replacement.
@MainActor
final class HealthWeightCacheStore {
    struct Snapshot: Codable {
        var connectionID: UUID
        var samples: [HealthWeightSample] = []
        var anchor: Data?
    }
    private let directory: URL
    private let writeFile: (Data, URL) throws -> Void
    init(directory: URL, writeFile: @escaping (Data, URL) throws -> Void = { data, url in
        try data.write(to: url, options: [.atomic, .completeFileProtection])
    }) {
        self.directory = directory
        self.writeFile = writeFile
    }

    func read(namespace: UUID, connectionID: UUID) throws -> Snapshot {
        let url = file(namespace)
        guard FileManager.default.fileExists(atPath: url.path) else { return Snapshot(connectionID: connectionID) }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: url))
        return snapshot.connectionID == connectionID ? snapshot : Snapshot(connectionID: connectionID)
    }

    func apply(_ changes: HealthWeightChanges, since: Date, namespace: UUID, connectionID: UUID) throws {
        var snapshot = try read(namespace: namespace, connectionID: connectionID)
        var samples: [UUID: HealthWeightSample] = [:]
        for sample in snapshot.samples { samples[sample.id] = sample }
        let removed = Set(changes.deleted)
        removed.forEach { samples.removeValue(forKey: $0) }
        for sample in changes.added where !removed.contains(sample.id) && sample.isValid && !sample.isOwnSample && sample.timestamp >= since {
            samples[sample.id] = sample
        }
        snapshot.samples = samples.values.sorted { $0.id.uuidString < $1.id.uuidString }
        snapshot.anchor = changes.anchor
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.protectionKey: FileProtectionType.complete])
        var protectedDirectory = directory
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(resources)
        let url = file(namespace)
        // Set all protection/backup metadata before the commit. A metadata failure must not advance the anchor.
        var temporary = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        defer { try? FileManager.default.removeItem(at: temporary) }
        try writeFile(JSONEncoder().encode(snapshot), temporary)
        try temporary.setResourceValues(resources)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary, options: .usingNewMetadataOnly)
        } else {
            try FileManager.default.moveItem(at: temporary, to: url)
        }
    }

    func remove(namespace: UUID) throws {
        let url = file(namespace)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
    private func file(_ namespace: UUID) -> URL { directory.appendingPathComponent(namespace.uuidString + ".json") }
}
