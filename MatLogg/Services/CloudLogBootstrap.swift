import Foundation

nonisolated enum CloudLogHistoryChoice: String, Codable, Sendable { case downloadOnly, includeLocalHistory }
nonisolated struct CloudLogHead: Codable, Sendable {
    let owner: UUID
    let historyEpoch: UUID
    let cursor: Int64
}
nonisolated struct CloudLogBootstrapManifest: Codable, Sendable {
    let owner: UUID
    let snapshotId: UUID
    let historyEpoch: UUID
    let upperCursor: Int64
    let totalCount: Int
}
nonisolated struct CloudLogBootstrapPage: Codable, Sendable {
    let owner: UUID
    let snapshotId: UUID
    let historyEpoch: UUID
    let upperCursor: Int64
    let totalCount: Int
    let offset: Int
    let changes: [CloudLogChange]
    let complete: Bool
}
nonisolated struct CloudLogBootstrapPlan: Codable, Sendable {
    let owner: UUID
    let snapshotId: UUID
    let historyEpoch: UUID
    let deviceId: UUID
    let choice: CloudLogHistoryChoice
    var manifest: CloudLogBootstrapManifest?
    var offset = 0
}
nonisolated struct CloudLogRecovery: Sendable {
    let entityId: UUID
    let local: CloudLogAggregate?
    let mutations: [CloudLogMutation]
    let server: CloudLogChange?
}

nonisolated extension CloudLogAggregate {
    /// Compare without depending on JSON object key ordering.
    func hasSameContent(as other: CloudLogAggregate) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self) == encoder.encode(other)
    }
}
