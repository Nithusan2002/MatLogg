import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogRepositoryTests {
    @Test func localOnlyPolicyBlocksEvenAnAuthenticatedDevelopmentRepository() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("policy.sqlite"))
        let transport = CloudLogPolicyTransport()
        let database = DatabaseService(store: store)
        let repository = try #require(database.makeDevelopmentCloudLogRepository(transport: transport))
        let owner = UUID()
        await repository.selectOwner(owner)
        await #expect(throws: CloudLogError.disabled) { try await repository.prepare(owner: owner, choice: .includeLocalHistory) }
        await #expect(throws: CloudLogError.disabled) { try await repository.sync(owner: owner) }
        #expect(await transport.requests == 0)
        #expect(try store.cloudLogBootstrapPlan(owner: owner) == nil)
    }

    @Test func explicitIntegrationPolicyPreparesWithoutUploadingAndRequiresCorrectOwner() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try LocalStore(databaseURL: directory.appendingPathComponent("policy.sqlite"))
        let transport = CloudLogPolicyTransport()
        let repository = try #require(DatabaseService(store: store).makeDevelopmentCloudLogRepository(transport: transport, uploadPolicy: .integrationTesting))
        let owner = UUID()
        await repository.selectOwner(owner)
        await #expect(throws: CloudLogError.bootstrapRequired) { try await repository.sync(owner: owner) }
        #expect(await transport.requests == 0)
        try await repository.prepare(owner: owner, choice: .downloadOnly)
        #expect(try store.cloudLogEpoch(owner: owner) == transport.epoch)
        #expect(await transport.pushes == 0)
        try await repository.sync(owner: owner)
        try store.beginCloudLogBootstrap(CloudLogBootstrapPlan(owner: owner, snapshotId: UUID(), historyEpoch: transport.epoch, deviceId: UUID(), choice: .downloadOnly))
        try await repository.deactivate(owner: owner)
        #expect(try store.cloudLogBootstrapPlan(owner: owner) == nil)
        #expect(try store.cloudLogConnection(owner: owner)?.enabled == false)
        await #expect(throws: CloudLogError.disabled) { try await repository.sync(owner: owner) }
        await repository.selectOwner(nil)
        await #expect(throws: CloudLogError.ownerChanged) { try await repository.sync(owner: owner) }
    }
}

private actor CloudLogPolicyTransport: CloudLogTransport {
    let epoch = UUID()
    var requests = 0
    var pushes = 0
    func head(owner: UUID) -> CloudLogHead { requests += 1; return CloudLogHead(owner: owner, historyEpoch: epoch, cursor: 0) }
    func beginBootstrap(_ plan: CloudLogBootstrapPlan) -> CloudLogBootstrapManifest {
        requests += 1
        return CloudLogBootstrapManifest(owner: plan.owner, snapshotId: plan.snapshotId, historyEpoch: epoch, upperCursor: 0, totalCount: 0)
    }
    func readBootstrap(_ plan: CloudLogBootstrapPlan) throws -> CloudLogBootstrapPage { throw CloudLogError.invalidResponse }
    func pull(after cursor: Int64, epoch: UUID, owner: UUID) -> CloudLogPage {
        requests += 1
        return CloudLogPage(owner: owner, changes: [], cursor: 0, historyEpoch: epoch)
    }
    func push(_ mutation: CloudLogMutation, owner: UUID) throws -> CloudLogReceipt {
        pushes += 1
        throw CloudLogError.invalidResponse
    }
}
