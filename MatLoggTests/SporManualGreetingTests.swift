import Foundation
import Testing
@testable import MatLogg

@Suite(.timeLimit(.minutes(1)))
@MainActor struct SporManualGreetingTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func tapBypassesDailyGateWithoutChangingAutomaticDate() async {
        let store = Store()
        store.lastHomeGreeting = date
        let player = Player()
        let model = make(player, store, duration: 0.001)
        await model.greet(context: .home)
        #expect(player.starts == 0)
        await model.greet(context: .home, trigger: .userInitiated)
        await model.greet(context: .home, trigger: .userInitiated)
        #expect(player.starts == 2 && store.lastHomeGreeting == date)
        #expect(!model.isBusy)
    }

    @Test func tapDoesNotConsumeUnusedAutomaticGreeting() async {
        let store = Store()
        let player = Player()
        let model = make(player, store, duration: 0.001)
        await model.greet(context: .home, trigger: .userInitiated)
        #expect(store.lastHomeGreeting == nil)
        await model.greet(context: .home)
        #expect(player.starts == 2 && store.lastHomeGreeting == date)
    }

    @Test func extraTapWhilePlayingIsIgnored() async {
        let store = Store()
        let player = Player()
        let model = make(player, store)
        let first = Task { await model.greet(context: .home, trigger: .userInitiated) }
        await player.waitForStart()
        await model.greet(context: .home, trigger: .userInitiated)
        model.waveOnTap()
        #expect(player.starts == 1 && model.isPlaying)
        model.stop()
        first.cancel()
        await first.value
        #expect(!model.isBusy && !player.playing && store.lastHomeGreeting == nil)
    }

    @Test func rapidTapActionsDoNotQueueGreetingsAndStopCancelsOwnedTask() async {
        let store = Store()
        let player = Player()
        let model = make(player, store)
        for _ in 0..<8 { model.waveOnTap() }
        await player.waitForStart()
        #expect(player.starts == 1 && model.isPlaying)
        model.stop()
        for _ in 0..<10 { await Task.yield() }
        #expect(!model.isBusy && !player.playing)
        #expect(player.starts == 1 && store.lastHomeGreeting == nil)
    }

    @Test func tapWhileLoadingDoesNotStartAnotherLookup() async {
        let assets = PendingAssets()
        let player = Player()
        let store = Store()
        let model = SporCompanionViewModel(player: player, assets: assets, preferences: store)
        model.waveOnTap()
        await assets.waitForRequest()
        #expect(model.isLoading && model.isBusy)
        model.waveOnTap()
        await model.greet(context: .home, trigger: .userInitiated)
        #expect(await assets.requests == 1)
        model.stop()
        await assets.finish()
        for _ in 0..<10 { await Task.yield() }
        #expect(!model.isBusy && player.starts == 0 && store.lastHomeGreeting == nil)
    }

    @Test func cancelledLookupClearsBusyStateAndAllowsRetry() async {
        let assets = PendingAssets()
        let player = Player()
        let model = SporCompanionViewModel(player: player, assets: assets, preferences: Store())
        let task = Task { await model.greet(context: .home, trigger: .userInitiated) }
        await assets.waitForRequest()
        task.cancel()
        await assets.finish()
        await task.value
        #expect(!model.isBusy && player.starts == 0)
    }

    @Test func manualFailureReturnsToIdleWithoutUsingDailyGate() async {
        let player = Player()
        player.fails = true
        let store = Store()
        let model = make(player, store, duration: 0.001)
        await model.greet(context: .home, trigger: .userInitiated)
        #expect(!model.isBusy && store.lastHomeGreeting == nil && player.starts == 0)
        player.fails = false
        await model.greet(context: .home, trigger: .userInitiated)
        #expect(player.starts == 1 && !model.isBusy)
    }

    private func make(_ player: Player, _ store: Store, duration: Double = 60) -> SporCompanionViewModel {
        SporCompanionViewModel(player: player, assets: Assets(duration: duration), preferences: store, now: { date })
    }
    private final class Store: SporGreetingStoring { var lastHomeGreeting: Date? }
    private struct Assets: MascotAssetProviding {
        let duration: Double
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: duration)
        }
    }
    private actor PendingAssets: MascotAssetProviding {
        private var pending: CheckedContinuation<MascotAsset, Never>?
        private(set) var requests = 0
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            requests += 1
            return await withCheckedContinuation { pending = $0 }
        }
        func waitForRequest() async { while requests == 0 { await Task.yield() } }
        func finish() {
            pending?.resume(returning: MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: 60))
            pending = nil
        }
    }
    private final class Player: MascotPlaying {
        var starts = 0
        var playing = false
        var fails = false
        func prepare(_ asset: MascotAsset) async throws { if fails { throw MascotAssetError.unavailable } }
        func resume(playing: Bool) { self.playing = playing; if playing { starts += 1 } }
        func suspend() { playing = false }
        func restart(playing: Bool) { self.playing = playing }
        func waitForStart() async { while starts == 0 { await Task.yield() } }
    }
}
