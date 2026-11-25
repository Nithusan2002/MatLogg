import Combine
import Foundation

@MainActor final class SporCompanionViewModel: ObservableObject {
    enum Context { case introduction, home }
    @Published private(set) var isPlaying = false
    private let player: any MascotPlaying
    private let assets: any MascotAssetProviding
    private let preferences: any SporGreetingStoring
    private let now: () -> Date
    private let calendar: () -> Calendar
    private var request = UUID()
    private var introduced = false

    init(player: any MascotPlaying, assets: any MascotAssetProviding,
         preferences: any SporGreetingStoring, now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { .current }) {
        self.player = player
        self.assets = assets
        self.preferences = preferences
        self.now = now
        self.calendar = calendar
    }

    func greet(context: Context) async {
        stop()
        let id = request
        guard context == .home
            ? SporGreetingPolicy.allows(now: now(), last: preferences.lastHomeGreeting, calendar: calendar())
            : !introduced else { return }
        do {
            let asset = try await assets.asset(for: .greeting)
            guard id == request, !Task.isCancelled else { return }
            try await player.prepare(asset)
            guard id == request, !Task.isCancelled else { return }
            player.resume(playing: true)
            isPlaying = true
            if context == .home { preferences.lastHomeGreeting = now() }
            else { introduced = true }
            try await Task.sleep(for: .seconds(asset.duration))
            guard id == request else { return }
            stop()
        } catch {
            guard id == request else { return }
            stop()
        }
    }

    func stop() {
        request = UUID()
        isPlaying = false
        player.suspend()
    }
}

nonisolated struct SporGreetingAssetRepository: MascotAssetProviding {
    let url: URL?
    func asset(for clip: MascotClip) async throws -> MascotAsset {
        guard clip == .greeting, let url else { throw MascotAssetError.unavailable }
        return MascotAsset(url: url, duration: 6)
    }
}
