import Foundation
import Testing
@testable import MatLogg

@Suite(.timeLimit(.minutes(1)))
@MainActor struct SporCompanionConcurrencyTests {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func stopDuringAssetLookupDiscardsLateAsset() async {
        let assets = PendingAssets()
        let player = Player()
        let store = Store()
        let model = make(assets, player, store)
        let task = Task { await model.greet(context: .home) }
        await assets.waitUntilRequested()
        model.stop()
        await assets.finish()
        await task.value
        #expect(player.prepares == 0 && player.starts == 0)
        #expect(!model.isPlaying && store.lastHomeGreeting == nil)
    }

    @Test func stopDuringPreparationDiscardsLateCompletion() async {
        let player = Player()
        player.holdsPreparation = true
        let store = Store()
        let model = make(Assets(), player, store)
        let task = Task { await model.greet(context: .home) }
        await player.waitUntilPrepared()
        model.stop()
        player.finishPreparation()
        await task.value
        #expect(player.starts == 0 && !model.isPlaying)
        #expect(store.lastHomeGreeting == nil)
    }

    @Test func supersededFailureDoesNotStopNewPlayback() async {
        let assets = PendingAssets()
        let player = Player()
        let store = Store()
        let model = make(assets, player, store)
        let first = Task { await model.greet(context: .home) }
        await assets.waitUntilRequested()
        await assets.releaseNext()
        let second = Task { await model.greet(context: .home) }
        await player.waitUntilStarted()
        await assets.failPending()
        await first.value
        #expect(model.isPlaying && player.playing)
        #expect(player.starts == 1 && store.lastHomeGreeting == date)
        second.cancel()
        await second.value
        #expect(!model.isPlaying && !player.playing)
    }

    @Test func cancellationStopsPlaybackAndKeepsDailyLimit() async {
        let player = Player()
        let store = Store()
        let model = make(Assets(), player, store)
        let task = Task { await model.greet(context: .home) }
        await player.waitUntilStarted()
        task.cancel()
        await task.value
        #expect(!model.isPlaying && !player.playing)
        #expect(store.lastHomeGreeting == date)
        await model.greet(context: .home)
        #expect(player.starts == 1)
    }

    @Test func interruptedIntroductionDoesNotReplayInSameViewModel() async {
        let player = Player()
        let model = make(Assets(), player, Store())
        let task = Task { await model.greet(context: .introduction) }
        await player.waitUntilStarted()
        model.stop()
        task.cancel()
        await task.value
        await model.greet(context: .introduction)
        #expect(player.starts == 1 && !model.isPlaying)
    }

    @Test func nextDayCanPlayAfterPreviousInstanceCompleted() async {
        let player = Player()
        let store = Store()
        let first = make(Assets(duration: 0.001), player, store)
        await first.greet(context: .home)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let tomorrow = date.addingTimeInterval(86400)
        let next = SporCompanionViewModel(player: player, assets: Assets(duration: 0.001),
            preferences: store, now: { tomorrow }, calendar: { calendar })
        await next.greet(context: .home)
        #expect(player.starts == 2 && store.lastHomeGreeting == tomorrow)
        #expect(!player.playing && !next.isPlaying)
    }

    @Test func assetLookupFailureDoesNotConsumeGreeting() async {
        let player = Player()
        let store = Store()
        let model = make(FailingAssets(), player, store)
        await model.greet(context: .home)
        #expect(player.prepares == 0 && player.starts == 0)
        #expect(!model.isPlaying && store.lastHomeGreeting == nil)
    }

    private func make(_ assets: any MascotAssetProviding, _ player: Player,
                      _ store: Store) -> SporCompanionViewModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return SporCompanionViewModel(player: player, assets: assets,
            preferences: store, now: { date }, calendar: { calendar })
    }
    private final class Store: SporGreetingStoring { var lastHomeGreeting: Date? }
    private struct Assets: MascotAssetProviding {
        var duration: Double = 60
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: duration)
        }
    }
    private struct FailingAssets: MascotAssetProviding {
        func asset(for clip: MascotClip) async throws -> MascotAsset { throw MascotAssetError.unavailable }
    }
    private actor PendingAssets: MascotAssetProviding {
        private var pending: CheckedContinuation<MascotAsset, Error>?
        private var requested = false
        var holdNext = true
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            if !holdNext { return MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: 60) }
            requested = true
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        func waitUntilRequested() async { while !requested { await Task.yield() } }
        func finish() {
            pending?.resume(returning: MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: 60))
            pending = nil
        }
        func failPending() { pending?.resume(throwing: MascotAssetError.unavailable); pending = nil }
        func releaseNext() { holdNext = false }
    }
    private final class Player: MascotPlaying {
        var prepares = 0
        var starts = 0
        var playing = false
        var holdsPreparation = false
        private var pending: CheckedContinuation<Void, Never>?
        func prepare(_ asset: MascotAsset) async throws {
            prepares += 1
            if holdsPreparation { await withCheckedContinuation { pending = $0 } }
        }
        func resume(playing: Bool) { self.playing = playing; if playing { starts += 1 } }
        func suspend() { playing = false }
        func restart(playing: Bool) { self.playing = playing }
        func finishPreparation() { pending?.resume(); pending = nil }
        func waitUntilPrepared() async { while prepares == 0 { await Task.yield() } }
        func waitUntilStarted() async { while starts == 0 { await Task.yield() } }
    }
}
