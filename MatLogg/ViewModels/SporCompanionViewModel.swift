import Combine
import Foundation

@MainActor final class SporCompanionViewModel: ObservableObject {
    enum Context { case introduction, home }
    enum Trigger { case automatic, userInitiated }
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var isReady = false
    var isBusy: Bool { isLoading || isPlaying }
    private let player: any MascotPlaying
    private let assets: any MascotAssetProviding
    private let preferences: any SporGreetingStoring
    private let now: () -> Date
    private let calendar: () -> Calendar
    private var request = UUID()
    private var introduced = false
    private var manualTask: Task<Void, Never>?
    private var preparedHomeAsset: MascotAsset?

    func setIdleMotionAllowed(_ allowed: Bool) {
        (player as? any MascotIdlePlaying)?.setIdleMotionEnabled(allowed)
    }

    /// Warm the visible Home scene independently of the daily greeting quota.
    func prepareHomeRest() async {
        guard !isBusy, !isReady else { return }
        let id = request
        isLoading = true
        do {
            let asset = try await assets.asset(for: .greeting)
            try Task.checkCancellation()
            guard id == request else { return }
            try await player.prepare(asset)
            try Task.checkCancellation()
            guard id == request else { return }
            preparedHomeAsset = asset
            player.resume(playing: false)
            isReady = true
            isLoading = false
        } catch {
            guard id == request else { return }
            stop()
        }
    }

    init(player: any MascotPlaying, assets: any MascotAssetProviding,
         preferences: any SporGreetingStoring, now: @escaping () -> Date = Date.init,
         calendar: @escaping () -> Calendar = { .current }) {
        self.player = player
        self.assets = assets
        self.preferences = preferences
        self.now = now
        self.calendar = calendar
    }

    func waveOnTap() {
        guard !isBusy else { return }
        manualTask?.cancel()
        manualTask = Task { [weak self] in
            await self?.greet(context: .home, trigger: .userInitiated)
        }
    }

    func greet(context: Context, trigger: Trigger = .automatic) async {
        guard !Task.isCancelled else { return }
        if trigger == .userInitiated, isBusy { return }
        if trigger == .automatic {
            manualTask?.cancel()
            manualTask = nil
        }
        resetPlayback()
        let id = request
        if trigger == .automatic {
            guard context == .home
                ? SporGreetingPolicy.allows(now: now(), last: preferences.lastHomeGreeting, calendar: calendar())
                : !introduced else { return }
        }
        isLoading = true
        do {
            let asset: MascotAsset
            if context == .home, let preparedHomeAsset {
                asset = preparedHomeAsset
                player.restart(playing: false)
            } else {
                asset = try await assets.asset(for: .greeting)
                guard id == request else { return }
                try Task.checkCancellation()
                try await player.prepare(asset)
            }
            guard id == request else { return }
            try Task.checkCancellation()
            if context == .home {
                preparedHomeAsset = asset
                isReady = true
            }
            player.resume(playing: true)
            isLoading = false
            isPlaying = true
            if trigger == .automatic {
                if context == .home { preferences.lastHomeGreeting = now() }
                else { introduced = true }
            }
            try await Task.sleep(for: .seconds(asset.duration))
            guard id == request else { return }
            finishPlayback()
        } catch {
            guard id == request else { return }
            stop()
        }
    }

    func stop() {
        setIdleMotionAllowed(false)
        manualTask?.cancel()
        manualTask = nil
        isReady = false
        preparedHomeAsset = nil
        resetPlayback()
    }

    private func finishPlayback() {
        // Keep the same entity, scene and surface visible at its original pose.
        resetPlayback()
    }

    private func resetPlayback() {
        request = UUID()
        isPlaying = false
        isLoading = false
        if isReady {
            player.restart(playing: false)
            player.resume(playing: false)
        } else {
            player.suspend()
        }
    }
}

nonisolated struct SporGreetingAssetRepository: MascotAssetProviding {
    let url: URL?
    func asset(for clip: MascotClip) async throws -> MascotAsset {
        guard clip == .greeting, let url else { throw MascotAssetError.unavailable }
        return MascotAsset(url: url, duration: 6)
    }
}
