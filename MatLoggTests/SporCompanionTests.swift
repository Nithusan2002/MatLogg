import Foundation
import Testing
@testable import MatLogg

@MainActor struct SporCompanionTests {
    private let today = Date(timeIntervalSince1970: 1_800_000_000)
    private var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(secondsFromGMT: 0)!
        return result
    }
    @Test func dailyLimitAndClockRollback() {
        #expect(SporGreetingPolicy.allows(now: today, last: nil, calendar: calendar))
        #expect(!SporGreetingPolicy.allows(now: today, last: today, calendar: calendar))
        #expect(SporGreetingPolicy.allows(now: today.addingTimeInterval(86400), last: today, calendar: calendar))
        #expect(!SporGreetingPolicy.allows(now: today.addingTimeInterval(-86400), last: today, calendar: calendar))
    }
    @Test func calendarDeterminesLocalDay() {
        let previous = Date(timeIntervalSince1970: 0)
        let now = previous.addingTimeInterval(23 * 3600)
        var oslo = calendar
        oslo.timeZone = TimeZone(secondsFromGMT: 3600)!
        #expect(!SporGreetingPolicy.allows(now: now, last: previous, calendar: calendar))
        #expect(SporGreetingPolicy.allows(now: now, last: previous, calendar: oslo))
    }
    @Test func successfulGreetingPersistsAndDoesNotRepeatAfterRecreation() async {
        let store = Store()
        let player = Player()
        let model = make(player, store)
        await model.greet(context: .home)
        #expect(store.lastHomeGreeting == today)
        #expect(player.starts == 1 && !model.isPlaying)
        await make(player, store).greet(context: .home)
        #expect(player.starts == 1)
    }
    @Test func resourceFailureDoesNotConsumeGreeting() async {
        let store = Store()
        let player = Player()
        player.fail = true
        await make(player, store).greet(context: .home)
        #expect(store.lastHomeGreeting == nil && player.starts == 0)
        player.fail = false
        await make(player, store).greet(context: .home)
        #expect(player.starts == 1)
    }
    @Test func cancelledLoadCannotStartOrConsumeGreeting() async {
        let store = Store()
        let player = Player()
        player.suspendsDuringPreparation = true
        let model = make(player, store)
        player.onPrepare = { model.stop() }
        await model.greet(context: .home)
        #expect(player.starts == 0 && store.lastHomeGreeting == nil)
    }
    @Test func introductionDoesNotConsumeHomeGreeting() async {
        let store = Store()
        let player = Player()
        let model = make(player, store)
        await model.greet(context: .introduction)
        await model.greet(context: .introduction)
        #expect(player.starts == 1 && store.lastHomeGreeting == nil)
    }
    @Test func persistedDateSurvivesRepositoryRecreation() throws {
        let name = "SporCompanionTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        SporGreetingPreferences(defaults: defaults).lastHomeGreeting = today
        #expect(SporGreetingPreferences(defaults: defaults).lastHomeGreeting == today)
    }
    @Test func absentBundledClipFailsWithoutStartingPlayer() async {
        do {
            _ = try await SporGreetingAssetRepository(url: nil).asset(for: .greeting)
            Issue.record("Expected a missing-asset error")
        } catch {
            #expect(error is MascotAssetError)
        }
    }
    private func make(_ player: Player, _ store: Store) -> SporCompanionViewModel {
        SporCompanionViewModel(player: player, assets: Assets(), preferences: store,
            now: { today }, calendar: { calendar })
    }
    private final class Store: SporGreetingStoring { var lastHomeGreeting: Date? }
    private struct Assets: MascotAssetProviding {
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            MascotAsset(url: URL(fileURLWithPath: "/unused.usdz"), duration: 0.001)
        }
    }
    private final class Player: MascotPlaying {
        var starts = 0
        var fail = false
        var suspendsDuringPreparation = false
        var onPrepare: (() -> Void)?
        func prepare(_ asset: MascotAsset) async throws {
            if fail { throw MascotAssetError.unavailable }
            if suspendsDuringPreparation { onPrepare?() }
        }
        func resume(playing: Bool) { if playing { starts += 1 } }
        func suspend() {}
        func restart(playing: Bool) {}
    }
}
