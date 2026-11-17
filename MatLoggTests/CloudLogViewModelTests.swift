import Foundation
import Testing
@testable import MatLogg

@MainActor
struct CloudLogViewModelTests {
    @Test func loginAndCancelledConfirmationNeverTransferHistory() async {
        let repository = CloudLogRepositoryProbe()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        await model.networkChanged(available: false)
        model.askToPrepare(.includeLocalHistory)
        model.confirmation = nil
        await model.confirm()
        #expect(await repository.prepares == 0)
        #expect(await repository.syncs == 0)
        model.askToPrepare(.downloadOnly)
        let approved = model.confirmation
        await model.confirm()
        await model.confirm(approved)
        #expect(await repository.prepares == 1)
        #expect(await repository.syncs == 0)
    }
    @Test func productionAndRemoteURLsNeverQualifyForDevelopmentComposition() {
        let callback = URL(string: "matlogg://auth/callback")!
        for address in ["https://example.supabase.co", "https://localhost", "http://127.0.0.1.example.com"] {
            #expect(!SupabaseConfiguration(url: URL(string: address)!, publishableKey: "synthetic", callbackURL: callback).isLocalCloudLogTestEnvironment)
        }
        #expect(SupabaseConfiguration(url: URL(string: "http://127.0.0.1:57321")!, publishableKey: "synthetic", callbackURL: callback).isLocalCloudLogTestEnvironment)
    }
    @Test func oldAccountConfirmationCannotRunForNewOwner() async {
        let repository = CloudLogRepositoryProbe()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        model.askToSync()
        let old = model.confirmation
        await model.selectOwner(UUID())
        await model.confirm(old)
        #expect(await repository.syncs == 0)
        #expect(model.message == nil)
    }
    @Test func unavailableAndLocalProfilesCannotStartOperations() async {
        let model = CloudLogViewModel(repository: nil)
        await model.selectOwner(UUID())
        model.askToPrepare(.includeLocalHistory)
        #expect(!model.isAvailable && model.confirmation == nil)
        let local = CloudLogViewModel(repository: CloudLogRepositoryProbe())
        await local.selectOwner(nil)
        local.askToSync()
        #expect(!local.isAvailable && local.confirmation == nil)
    }
    @Test func failedSyncRetainsRetryAndDoesNotReportSuccess() async {
        let repository = CloudLogRepositoryProbe()
        await repository.failNextSync()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        model.askToSync()
        await model.confirm()
        #expect(model.errorMessage != nil && model.message == nil && !model.isBusy)
        model.askToSync()
        await model.confirm()
        #expect(model.errorMessage == nil && model.message != nil && !model.isBusy)
    }
    @Test func accountChangeSuppressesLateSuccess() async {
        let repository = CloudLogRepositoryProbe()
        await repository.suspendNextSync()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        model.askToSync()
        let task = Task { await model.confirm() }
        while !(await repository.waiting) { await Task.yield() }
        await model.selectOwner(nil)
        await repository.release()
        await task.value
        #expect(!model.isAvailable && !model.isBusy && model.message == nil && model.errorMessage == nil)
    }
    @Test func automaticSyncRequiresPersistedOptInAndNetwork() async {
        let repository = CloudLogRepositoryProbe()
        let model = CloudLogViewModel(repository: repository)
        let owner = UUID()
        await model.selectOwner(owner)
        await model.networkChanged(available: true)
        #expect(await repository.syncs == 0)
        await repository.setEnabled(true)
        await model.selectOwner(owner)
        await model.networkChanged(available: false)
        await model.syncIfEnabled()
        #expect(await repository.syncs == 0)
        await model.networkChanged(available: true)
        #expect(await repository.syncs == 1)
        await model.selectOwner(nil)
        await model.syncIfEnabled()
        #expect(await repository.syncs == 1)
    }
    @Test func disablingDuringSyncSuppressesItsLateResult() async {
        let repository = CloudLogRepositoryProbe()
        await repository.setEnabled(true)
        await repository.suspendNextSync()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        let run = Task { await model.syncIfEnabled() }
        while !(await repository.waiting) { await Task.yield() }
        model.askToDeactivate()
        await model.confirm()
        #expect(!model.isEnabled && !model.isBusy)
        let stoppedMessage = model.message
        await repository.release()
        await run.value
        #expect(model.message == stoppedMessage && !model.isEnabled)
        await model.syncIfEnabled()
        #expect(await repository.syncs == 1)
    }
    @Test func persistedActivationCanResumeWhenBootstrapReviewsAreNotReady() async {
        let repository = CloudLogRepositoryProbe()
        await repository.setEnabled(true)
        await repository.failNextReview()
        let model = CloudLogViewModel(repository: repository)
        await model.selectOwner(UUID())
        #expect(model.isEnabled)
        await model.networkChanged(available: true)
        #expect(await repository.syncs == 1)
        #expect(model.errorMessage == nil)
    }
}

private actor CloudLogRepositoryProbe: CloudLogRepository {
    var prepares = 0
    var syncs = 0
    var fails = false
    var suspend = false
    var waiting = false
    var continuation: CheckedContinuation<Void, Never>?
    var enabled = false
    var reviewFails = false
    func selectOwner(_ owner: UUID?) {}
    func isEnabled(owner: UUID) -> Bool { enabled }
    func deactivate(owner: UUID) { enabled = false }
    func setEnabled(_ value: Bool) { enabled = value }
    func reviews(owner: UUID) throws -> [CloudLogReview] {
        if reviewFails { reviewFails = false; throw CloudLogError.bootstrapRequired }
        return []
    }
    func failNextReview() { reviewFails = true }
    func prepare(owner: UUID, choice: CloudLogHistoryChoice) { prepares += 1; enabled = true }
    func sync(owner: UUID) async throws {
        syncs += 1
        if fails { fails = false; throw CloudLogError.disabled }
        if suspend { await withCheckedContinuation { continuation = $0; waiting = true } }
    }
    func resolve(_ review: CloudLogReview, choice: CloudLogResolution, owner: UUID) {}
    func failNextSync() { fails = true }
    func suspendNextSync() { suspend = true }
    func release() { continuation?.resume(); continuation = nil }
}
