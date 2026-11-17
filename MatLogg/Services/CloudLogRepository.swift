import Foundation

nonisolated protocol CloudLogRepository: Sendable {
    func selectOwner(_ owner: UUID?) async
    func isEnabled(owner: UUID) async throws -> Bool
    func deactivate(owner: UUID) async throws
    func reviews(owner: UUID) async throws -> [CloudLogReview]
    func prepare(owner: UUID, choice: CloudLogHistoryChoice) async throws
    func sync(owner: UUID) async throws
    func resolve(_ review: CloudLogReview, choice: CloudLogResolution, owner: UUID) async throws
}

/// Account-bound development path. No retry timers and no implicit enrollment.
actor DevelopmentCloudLogRepository: CloudLogRepository {
    private let store: LocalStore
    private let coordinator: CloudLogSyncCoordinator
    private let device = UUID()
    private let uploadsAllowed: Bool
    private var owner: UUID?
    private var busy = false
    private var generation = UUID()
    init(store: LocalStore, transport: any CloudLogTransport, uploadsAllowed: Bool = false) {
        self.store = store
        self.uploadsAllowed = uploadsAllowed
        store.configureCloudLogRouting(allowed: uploadsAllowed)
        coordinator = CloudLogSyncCoordinator(store: store, transport: transport)
    }
    func selectOwner(_ owner: UUID?) async {
        self.owner = owner
        generation = UUID()
        store.selectCloudLogReadOwner(owner)
        await coordinator.setOwner(owner)
    }
    func isEnabled(owner: UUID) throws -> Bool {
        guard self.owner == owner else { throw CloudLogError.ownerChanged }
        guard uploadsAllowed else { return false }
        return try store.cloudLogConnection(owner: owner)?.enabled == true
    }
    func deactivate(owner: UUID) async throws {
        guard uploadsAllowed, self.owner == owner else { throw CloudLogError.disabled }
        generation = UUID()
        try store.setCloudLogEnabled(false, owner: owner, device: device, discardBootstrap: true)
        await coordinator.setOwner(nil)
    }
    func reviews(owner: UUID) throws -> [CloudLogReview] {
        guard self.owner == owner else { throw CloudLogError.ownerChanged }
        return try store.cloudLogReviews(owner: owner)
    }
    private func requireRun(_ owner: UUID) throws {
        guard uploadsAllowed else { throw CloudLogError.disabled }
        guard self.owner == owner, !busy else { throw CloudLogError.ownerChanged }
        try Task.checkCancellation()
    }
    func prepare(owner: UUID, choice: CloudLogHistoryChoice) async throws {
        try requireRun(owner)
        busy = true
        defer { busy = false }
        let run = generation
        // Track edits/deletions made during bootstrap as local recovery candidates.
        try store.setCloudLogEnabled(false, owner: owner, device: device)
        await coordinator.setOwner(owner)
        try await coordinator.transferHistory(owner: owner, choice: choice, device: device, allowed: uploadsAllowed)
        guard self.owner == owner, run == generation else { throw CloudLogError.ownerChanged }
        try store.setCloudLogEnabled(true, owner: owner, device: device)
    }
    func sync(owner: UUID) async throws {
        try requireRun(owner)
        // First enrollment must always go through the history-choice screen.
        guard try store.cloudLogEpoch(owner: owner) != nil else { throw CloudLogError.bootstrapRequired }
        guard try store.cloudLogConnection(owner: owner)?.enabled == true else { throw CloudLogError.disabled }
        busy = true
        defer { busy = false }
        try await coordinator.sync(owner: owner, allowed: uploadsAllowed)
    }
    func resolve(_ review: CloudLogReview, choice: CloudLogResolution, owner: UUID) throws {
        try requireRun(owner)
        try store.resolveCloudLog(review, choice: choice, owner: owner, device: device)
    }
}
