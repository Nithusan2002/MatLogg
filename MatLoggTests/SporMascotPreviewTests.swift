#if DEBUG && SPOR_MASCOT_QA
import Foundation
import Testing
@testable import MatLogg

@MainActor struct SporMascotPreviewTests {
    @Test func playbackAndManualPauseSurviveBackground() async {
        let player = Player()
        let model = SporMascotPreviewViewModel(assets: Assets(), player: player)
        await model.loadSelection()
        #expect(model.phase == .ready && model.isPlaying)
        model.setActive(false)
        #expect(!model.isPlaying && player.suspended)
        model.setActive(true)
        #expect(model.isPlaying)
        model.togglePlayback()
        model.setActive(false)
        model.setActive(true)
        #expect(!model.isPlaying)
        model.restart()
        #expect(player.restarts == [false])
    }

    @Test func reducedMotionRequiresExplicitPlaybackAndDoesNotAutostartOnReturn() async {
        let player = Player()
        let model = SporMascotPreviewViewModel(assets: Assets(), player: player)
        model.setReducedMotion(true)
        await model.loadSelection()
        #expect(!model.isPlaying)
        model.togglePlayback()
        #expect(model.isPlaying)
        model.setActive(false)
        model.setActive(true)
        #expect(model.isPlaying)
        model.setReducedMotion(false)
        model.setReducedMotion(true)
        #expect(!model.isPlaying)
    }

    @Test func failedLoadCanRetry() async {
        let player = Player()
        player.failNext = true
        let model = SporMascotPreviewViewModel(assets: Assets(), player: player)
        await model.loadSelection()
        #expect(model.phase == .failed && !model.isPlaying)
        await model.loadSelection()
        #expect(model.phase == .ready && model.isPlaying)
    }

    @Test func olderClipLoadCannotReplaceLatestChoice() async {
        let assets = GatedAssets()
        let player = Player()
        let model = SporMascotPreviewViewModel(assets: assets, player: player)
        let first = Task { await model.loadSelection() }
        await assets.waitFor(.idle)
        model.select(.greeting)
        let second = Task { await model.loadSelection() }
        await assets.waitFor(.greeting)
        await assets.finish(.greeting)
        await second.value
        await assets.finish(.idle)
        await first.value
        #expect(model.clip == .greeting && model.phase == .ready)
        #expect(player.prepared.map(\.url.lastPathComponent) == ["greeting.usdz"])
    }

    @Test func cancelledLoadDoesNotPrepareScene() async {
        let assets = GatedAssets()
        let player = Player()
        let model = SporMascotPreviewViewModel(assets: assets, player: player)
        let task = Task { await model.loadSelection() }
        await assets.waitFor(.idle)
        task.cancel()
        await assets.finish(.idle)
        await task.value
        #expect(player.prepared.isEmpty && !model.isPlaying)
    }

    @Test func manifestRejectsMissingFilesTraversalAndInvalidDuration() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = BundledMascotAssetRepository(directory: directory)
        for entry in ["\"file\":\"../escape.usdz\",\"duration\":6", "\"file\":\"idle.usdz\",\"duration\":0", "\"file\":\"absent.usdz\",\"duration\":6"] {
            try Data("{\"schemaVersion\":1,\"clips\":{\"idle\":{\(entry)}}}".utf8)
                .write(to: directory.appendingPathComponent("manifest.json"))
            await #expect(throws: (any Error).self) { try await repository.asset(for: .idle) }
        }
        try Data().write(to: directory.appendingPathComponent("idle.usdz"))
        try Data("{\"schemaVersion\":1,\"clips\":{\"idle\":{\"file\":\"idle.usdz\",\"duration\":6}}}".utf8)
            .write(to: directory.appendingPathComponent("manifest.json"))
        let asset = try await repository.asset(for: .idle)
        #expect(asset.duration == 6 && asset.url.lastPathComponent == "idle.usdz")
    }

    private struct Assets: MascotAssetProviding {
        nonisolated func asset(for clip: MascotClip) async throws -> MascotAsset {
            MascotAsset(url: URL(fileURLWithPath: "/tmp/\(clip.rawValue).usdz"), duration: 6)
        }
    }
    private actor GatedAssets: MascotAssetProviding {
        var pending: [MascotClip: CheckedContinuation<MascotAsset, Never>] = [:]
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            await withCheckedContinuation { pending[clip] = $0 }
        }
        func waitFor(_ clip: MascotClip) async {
            while pending[clip] == nil { await Task.yield() }
        }
        func finish(_ clip: MascotClip) {
            pending.removeValue(forKey: clip)?.resume(returning:
                MascotAsset(url: URL(fileURLWithPath: "/tmp/\(clip.rawValue).usdz"), duration: 6))
        }
    }
    private final class Player: MascotPlaying {
        var prepared: [MascotAsset] = []
        var restarts: [Bool] = []
        var suspended = true
        var failNext = false
        func prepare(_ asset: MascotAsset) async throws {
            if failNext { failNext = false; throw MascotAssetError.unavailable }
            prepared.append(asset)
        }
        func resume(playing: Bool) { suspended = false }
        func suspend() { suspended = true }
        func restart(playing: Bool) { restarts.append(playing) }
    }
}
#endif
