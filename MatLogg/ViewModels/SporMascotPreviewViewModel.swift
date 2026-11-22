#if DEBUG && SPOR_MASCOT_QA
import SwiftUI
import Combine

@MainActor final class SporMascotPreviewViewModel: ObservableObject {
    enum Phase: Equatable { case idle, loading, ready, failed }
    enum Size: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var title: String { switch self { case .small: "Liten"; case .medium: "Middels"; case .large: "Stor" } }
        var points: CGFloat { switch self { case .small: 96; case .medium: 180; case .large: 280 } }
    }
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var title: String { switch self { case .system: "System"; case .light: "Lys"; case .dark: "Mørk" } }
        var colorScheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
    }
    @Published private(set) var clip: MascotClip = .idle
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isPlaying = false
    @Published var size: Size = .medium
    @Published var appearance: Appearance = .system
    private let assets: any MascotAssetProviding
    private let player: any MascotPlaying
    private var request = UUID()
    private var wantsPlayback = true
    private var active = true
    private var reducedMotion = false

    init(assets: any MascotAssetProviding, player: any MascotPlaying) {
        self.assets = assets
        self.player = player
    }

    func select(_ clip: MascotClip) { self.clip = clip }

    func loadSelection() async {
        let id = UUID()
        request = id
        phase = .loading
        isPlaying = false
        player.suspend()
        do {
            let asset = try await assets.asset(for: clip)
            guard request == id, !Task.isCancelled else { return }
            try await player.prepare(asset)
            guard request == id, !Task.isCancelled else { return }
            phase = .ready
            applyPlayback()
        } catch {
            guard request == id, !Task.isCancelled else { return }
            phase = .failed
            isPlaying = false
            player.suspend()
        }
    }

    func togglePlayback() {
        guard phase == .ready else { return }
        wantsPlayback.toggle()
        applyPlayback()
    }
    func restart() {
        guard phase == .ready else { return }
        player.restart(playing: active && wantsPlayback)
        applyPlayback()
    }
    func setActive(_ active: Bool) { self.active = active; applyPlayback() }
    func setReducedMotion(_ enabled: Bool) {
        guard reducedMotion != enabled else { return }
        reducedMotion = enabled
        if enabled { wantsPlayback = false }
        applyPlayback()
    }
    private func applyPlayback() {
        isPlaying = phase == .ready && active && wantsPlayback
        if active, phase == .ready { player.resume(playing: isPlaying) }
        else { player.suspend() }
    }
}
#endif
