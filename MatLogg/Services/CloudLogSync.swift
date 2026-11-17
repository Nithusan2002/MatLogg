import Foundation
import Supabase

nonisolated enum CloudLogError: Error, Equatable { case invalidData, ownerChanged, disabled, conflict, invalidResponse, historyEpochMismatch, snapshotExpired, bootstrapRequired, historyChoiceMismatch, historyReviewRequired }

/// V2 log aggregate. Product data is a historical snapshot, not a mutable shared catalog row.
nonisolated struct CloudLogAggregate: Codable, Sendable {
    let log: FoodLog
    let product: Product

    init(log: FoodLog, product: Product) throws {
        if log.amountUnit == nil {
            // Legacy logs have a documented grams default; do not infer missing nutrition.
            self.log = FoodLog(id:log.id,userId:log.userId,productId:log.productId,mealType:log.mealType,
                amountG:log.amountG,amountUnit:log.resolvedAmountUnit,portionSelection:log.portionSelection,
                nutritionPreparation:log.nutritionPreparation,nutritionSource:log.nutritionSource,
                loggedDate:log.loggedDate,loggedTime:log.loggedTime,calories:log.calories,
                proteinG:log.proteinG,carbsG:log.carbsG,fatG:log.fatG,createdAt:log.createdAt,isSynced:log.isSynced)
        } else { self.log = log }
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(product)) as? [String: Any]
        object?.removeValue(forKey: "localImageData")
        object?.removeValue(forKey: "imageUrl")
        guard let object else { throw CloudLogError.invalidData }
        self.product = try JSONDecoder().decode(Product.self, from: JSONSerialization.data(withJSONObject: object))
        try validate(owner: log.userId, id: log.id)
    }

    func validate(owner: UUID, id: UUID) throws {
        guard log.userId == owner, log.id == id, log.productId == product.id,
              product.localImageData == nil, product.imageUrl == nil,
              !product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [log.amountG, log.calories, log.proteinG, log.carbsG, log.fatG,
               product.caloriesPer100g, product.proteinGPer100g, product.carbsGPer100g, product.fatGPer100g]
                .allSatisfy({ $0.isFinite && $0 >= 0 }), log.amountG > 0,
              ["frokost", "lunsj", "middag", "snacks"].contains(log.mealType),
              [log.loggedDate, log.loggedTime, log.createdAt, product.createdAt].allSatisfy({ $0.timeIntervalSince1970.isFinite }),
              log.portionSelection?.matches(amount: Double(log.amountG), unit: log.resolvedAmountUnit) != false else {
            throw CloudLogError.invalidData
        }
    }
}

nonisolated struct CloudLogMutation: Codable, Sendable {
    let eventId: UUID
    let deviceId: UUID
    let entityId: UUID
    let schemaVersion: Int
    let type: String
    var baseRevision: Int64?
    let payload: CloudLogAggregate?
    var historyEpoch: UUID? = nil
}
nonisolated struct CloudLogChange: Codable, Sendable {
    let entityId: UUID
    let revision: Int64
    let deleted: Bool
    let payload: CloudLogAggregate?
}
nonisolated struct CloudLogConflict: Sendable {
    let local: CloudLogMutation
    let server: CloudLogReceipt
    let current: CloudLogChange
}
nonisolated struct CloudLogReceipt: Codable, Sendable {
    let eventId: UUID
    let status: String
    let change: CloudLogChange
    var historyEpoch: UUID? = nil
}
nonisolated struct CloudLogSyncResult: Sendable {
    let cursor: Int64
    let conflicts: [CloudLogConflict]
    let recovery: [CloudLogRecovery]
}
nonisolated struct CloudLogPage: Codable, Sendable {
    let owner: UUID
    let changes: [CloudLogChange]
    let cursor: Int64
    var historyEpoch: UUID? = nil
}

nonisolated protocol CloudLogTransport: Sendable {
    func push(_ mutation: CloudLogMutation, owner: UUID) async throws -> CloudLogReceipt
    func pull(after cursor: Int64, epoch: UUID, owner: UUID) async throws -> CloudLogPage
    func head(owner: UUID) async throws -> CloudLogHead
    func beginBootstrap(_ plan: CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest
    func readBootstrap(_ plan: CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage
}

nonisolated protocol CloudLogSyncStorage: Sendable {
    func cloudLogEpoch(owner: UUID) throws -> UUID?
    func cloudLogRecovery(owner: UUID) throws -> [CloudLogRecovery]
    func cloudLogBootstrapPlan(owner: UUID) throws -> CloudLogBootstrapPlan?
    func beginCloudLogBootstrap(_ plan: CloudLogBootstrapPlan) throws
    func saveCloudLogManifest(_ manifest: CloudLogBootstrapManifest, owner: UUID) throws
    func stageCloudLogBootstrap(_ page: CloudLogBootstrapPage, owner: UUID) throws
    func finishCloudLogBootstrap(owner: UUID) throws
    func cancelCloudLogBootstrap(owner: UUID) throws
    func cloudLogConflictCandidates(owner: UUID) throws -> [CloudLogConflict]
    func nextCloudLogMutation(owner: UUID) throws -> CloudLogMutation?
    func applyCloudLogReceipt(_ receipt: CloudLogReceipt, mutation: CloudLogMutation, owner: UUID) throws
    func cloudLogCursor(owner: UUID) throws -> Int64
    func applyCloudLogPage(_ page: CloudLogPage, after cursor: Int64, owner: UUID) throws
}

/// Composed only for explicit development testing. Each run requires the active owner and permission.
actor CloudLogSyncCoordinator {
    private let store: any CloudLogSyncStorage
    private let transport: any CloudLogTransport
    private var activeOwner: UUID?
    private var generation = UUID()
    private var running = false
    init(store: any CloudLogSyncStorage, transport: any CloudLogTransport) { self.store = store; self.transport = transport }
    func setOwner(_ owner: UUID?) { activeOwner = owner; generation = UUID() }
    @discardableResult
    func sync(owner: UUID, allowed: Bool) async throws -> CloudLogSyncResult {
        guard allowed else { throw CloudLogError.disabled }
        guard activeOwner == owner, !running else { throw CloudLogError.ownerChanged }
        running = true
        defer { running = false }
        let run = generation
        let head = try await transport.head(owner: owner)
        try checkRun(owner: owner, run: run)
        guard head.owner == owner else { throw CloudLogError.invalidResponse }
        if try store.cloudLogEpoch(owner: owner) != head.historyEpoch || store.cloudLogBootstrapPlan(owner: owner) != nil {
            try await bootstrap(owner: owner, head: head, choice: .downloadOnly, device: UUID(), run: run)
        }
        while let mutation = try store.nextCloudLogMutation(owner: owner) {
            let receipt = try await transport.push(mutation, owner: owner)
            guard activeOwner == owner, generation == run else { throw CloudLogError.ownerChanged }
            try Task.checkCancellation()
            try store.applyCloudLogReceipt(receipt, mutation: mutation, owner: owner)
        }
        while true {
            let cursor = try store.cloudLogCursor(owner: owner)
            guard let epoch = try store.cloudLogEpoch(owner: owner) else { throw CloudLogError.bootstrapRequired }
            let page = try await transport.pull(after: cursor, epoch: epoch, owner: owner)
            guard activeOwner == owner, generation == run else { throw CloudLogError.ownerChanged }
            try Task.checkCancellation()
            try store.applyCloudLogPage(page, after: cursor, owner: owner)
            if page.changes.count < 100 { break }
        }
        return CloudLogSyncResult(cursor: try store.cloudLogCursor(owner: owner), conflicts: try store.cloudLogConflictCandidates(owner: owner), recovery: try store.cloudLogRecovery(owner: owner))
    }
    /// Explicit history choice; never infers consent from login or from an old v1 queue.
    @discardableResult
    func transferHistory(owner: UUID, choice: CloudLogHistoryChoice, device: UUID, allowed: Bool) async throws -> CloudLogSyncResult {
        guard allowed else { throw CloudLogError.disabled }
        guard activeOwner == owner, !running else { throw CloudLogError.ownerChanged }
        running = true
        defer { running = false }
        let run = generation
        let head = try await transport.head(owner: owner)
        try checkRun(owner: owner, run: run)
        guard head.owner == owner else { throw CloudLogError.invalidResponse }
        try await bootstrap(owner: owner, head: head, choice: choice, device: device, run: run, explicitChoice: true)
        return CloudLogSyncResult(cursor: try store.cloudLogCursor(owner: owner), conflicts: try store.cloudLogConflictCandidates(owner: owner), recovery: try store.cloudLogRecovery(owner: owner))
    }
    private func checkRun(owner: UUID, run: UUID) throws {
        try Task.checkCancellation()
        guard activeOwner == owner, generation == run else { throw CloudLogError.ownerChanged }
    }
    private func bootstrap(owner: UUID, head: CloudLogHead, choice: CloudLogHistoryChoice, device: UUID, run: UUID, explicitChoice: Bool = false) async throws {
        if explicitChoice, let previous = try store.cloudLogBootstrapPlan(owner:owner), previous.choice != choice {
            throw CloudLogError.historyChoiceMismatch
        }
        if let previous = try store.cloudLogBootstrapPlan(owner: owner), previous.historyEpoch != head.historyEpoch {
            try store.cancelCloudLogBootstrap(owner: owner)
        }
        if try store.cloudLogBootstrapPlan(owner: owner) == nil {
            try store.beginCloudLogBootstrap(CloudLogBootstrapPlan(owner: owner, snapshotId: UUID(), historyEpoch: head.historyEpoch, deviceId: device, choice: choice))
        }
        do {
            guard var plan = try store.cloudLogBootstrapPlan(owner: owner) else { throw CloudLogError.invalidResponse }
            if plan.manifest == nil {
                let manifest = try await transport.beginBootstrap(plan)
                try checkRun(owner: owner, run: run)
                try store.saveCloudLogManifest(manifest, owner: owner)
            }
            while true {
                guard let updated = try store.cloudLogBootstrapPlan(owner: owner), let manifest = updated.manifest else { throw CloudLogError.invalidResponse }
                plan = updated
                if plan.offset == manifest.totalCount { break }
                let page = try await transport.readBootstrap(plan)
                try checkRun(owner: owner, run: run)
                try store.stageCloudLogBootstrap(page, owner: owner)
            }
            let finalHead = try await transport.head(owner: owner)
            try checkRun(owner: owner, run: run)
            guard finalHead.owner == owner, finalHead.historyEpoch == head.historyEpoch else { throw CloudLogError.historyEpochMismatch }
            try store.finishCloudLogBootstrap(owner: owner)
        } catch CloudLogError.snapshotExpired {
            try store.cancelCloudLogBootstrap(owner: owner)
            throw CloudLogError.snapshotExpired
        }
    }

}

/// Token identity is checked before each RPC; returned page ownership is checked again locally.
nonisolated final class SupabaseCloudLogTransport: CloudLogTransport, Sendable {
    private let client: SupabaseClient
    init(client: SupabaseClient) { self.client = client }
    private func checkOwner(_ owner: UUID) async throws {
        guard try await client.auth.session.user.id == owner else { throw CloudLogError.ownerChanged }
    }
    func push(_ mutation: CloudLogMutation, owner: UUID) async throws -> CloudLogReceipt {
        try await checkOwner(owner)
        // Freeze the wire codec independently of Supabase's default ISO date strategy.
        let raw = try JSONDecoder().decode(AnyJSON.self, from: JSONEncoder().encode(mutation))
        let response = try await mapped { try await self.client.rpc("push_log_v2", params: ["mutation": raw]).execute().data }
        let receipt = try JSONDecoder().decode(CloudLogReceipt.self, from: response)
        guard receipt.historyEpoch == mutation.historyEpoch, receipt.historyEpoch != nil else { throw CloudLogError.historyEpochMismatch }
        return receipt
    }
    func pull(after cursor: Int64, epoch: UUID, owner: UUID) async throws -> CloudLogPage {
        try await checkOwner(owner)
        let response = try await mapped { try await self.client.rpc("pull_logs_v2", params: Pull(after_cursor: cursor, history_epoch: epoch)).execute().data }
        let page = try JSONDecoder().decode(CloudLogPage.self, from: response)
        guard page.historyEpoch == epoch else { throw CloudLogError.historyEpochMismatch }
        return page
    }
    func head(owner: UUID) async throws -> CloudLogHead {
        try await checkOwner(owner)
        let response = try await mapped { try await self.client.rpc("log_sync_head_v2").execute().data }
        return try JSONDecoder().decode(CloudLogHead.self, from: response)
    }
    func beginBootstrap(_ plan: CloudLogBootstrapPlan) async throws -> CloudLogBootstrapManifest {
        try await checkOwner(plan.owner)
        let response = try await mapped { try await self.client.rpc("begin_log_bootstrap_v2", params: Begin(snapshot_id:plan.snapshotId,expected_epoch:plan.historyEpoch)).execute().data }
        return try JSONDecoder().decode(CloudLogBootstrapManifest.self, from:response)
    }
    func readBootstrap(_ plan: CloudLogBootstrapPlan) async throws -> CloudLogBootstrapPage {
        try await checkOwner(plan.owner)
        let response = try await mapped { try await self.client.rpc("read_log_bootstrap_v2", params: Read(snapshot_id:plan.snapshotId,page_offset:plan.offset)).execute().data }
        return try JSONDecoder().decode(CloudLogBootstrapPage.self, from:response)
    }
    private func mapped(_ work: () async throws -> Data) async throws -> Data {
        do { return try await work() }
        catch let error as PostgrestError {
            if error.message == "HISTORY_EPOCH_MISMATCH" { throw CloudLogError.historyEpochMismatch }
            if error.message == "SNAPSHOT_EXPIRED" { throw CloudLogError.snapshotExpired }
            throw error
        }
    }
    nonisolated private struct Pull: Encodable { let after_cursor: Int64; let history_epoch: UUID }
    nonisolated private struct Begin: Encodable { let snapshot_id: UUID; let expected_epoch: UUID }
    nonisolated private struct Read: Encodable { let snapshot_id: UUID; let page_offset: Int }
}
