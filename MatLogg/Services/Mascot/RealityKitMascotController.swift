import Combine
import RealityKit
import UIKit

@MainActor final class RealityKitMascotController: MascotPlaying, MascotIdlePlaying {
    private var view: ARView?
    private let makeRenderer: @MainActor () -> ARView
    private var backgroundColor = UIColor.clear
    let host = UIView()
    #if DEBUG && SPOR_MASCOT_QA
    let poster: UIImage?
    #endif
    private let anchor = AnchorEntity(world: .zero)
    private var model: Entity?
    private var animation: AnimationResource?
    private var playback: AnimationPlaybackController?
    private var generation = UUID()
    private let loops: Bool
    private var preparedURL: URL?
    private var preparedDuration: Double?
    private var idleEnabled = false
    private var greetingPlaying = false
    private var idleUpdate: (any Cancellable)?
    private var idleTime: TimeInterval = 0
    private var idleBlend: Float = 0
    private var restScale = SIMD3<Float>(repeating: 1)
    private var restPosition = SIMD3<Float>(repeating: 0)
    private var restBottomOffset: Float = 0

    init(loops: Bool = true, makeRenderer: @escaping @MainActor () -> ARView = {
        ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
    }) {
        self.loops = loops
        self.makeRenderer = makeRenderer
        #if DEBUG && SPOR_MASCOT_QA
        poster = Bundle.main.url(forResource: "poster", withExtension: "png", subdirectory: "SporMascotQA")
            .flatMap { UIImage(contentsOfFile: $0.path) }
        #endif
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 32
        // Reserve room for the raised flipper, not just the rest-pose bounds.
        camera.look(at: .zero, from: [0, 0, 3.5], relativeTo: nil)
        anchor.addChild(camera)
        let key = DirectionalLight()
        key.light.intensity = 2400
        key.look(at: .zero, from: [2, 3, 4], relativeTo: nil)
        anchor.addChild(key)
        let fill = DirectionalLight()
        fill.light.intensity = 800
        fill.look(at: .zero, from: [-2, 1, 3], relativeTo: nil)
        anchor.addChild(fill)
    }

    private func prepareRenderer() {
        guard view == nil else { return }
        let renderer = makeRenderer()
        renderer.isAccessibilityElement = false
        renderer.accessibilityElementsHidden = true
        renderer.renderOptions.insert([.disableMotionBlur, .disableDepthOfField])
        renderer.environment.background = .color(backgroundColor)
        renderer.scene.addAnchor(anchor)
        renderer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view = renderer
    }

    func prepare(_ asset: MascotAsset) async throws {
        let id = UUID()
        generation = id
        if preparedURL == asset.url, preparedDuration == asset.duration, model != nil {
            restart(playing: false)
            return
        }
        guard let entity = try await Entity.loadAsync(contentsOf: asset.url).values.first(where: { _ in true }) else {
            throw MascotAssetError.unavailable
        }
        guard generation == id, !Task.isCancelled else { throw CancellationError() }
        // Prefer the imported global scene animation: it includes skin and face.
        guard let clip = entity.availableAnimations.first,
              clip.definition.duration.isFinite,
              abs(clip.definition.duration - asset.duration) < 0.05 else {
            throw MascotAssetError.invalidManifest
        }
        entity.scale *= 0.5
        let bounds = entity.visualBounds(relativeTo: nil)
        guard bounds.extents.y > 0, bounds.extents.y.isFinite else { throw MascotAssetError.invalidManifest }
        let bottomOffset = bounds.min.y - entity.position.y
        entity.position -= bounds.center
        playback?.stop()
        playback = nil
        model?.removeFromParent()
        model = entity
        restScale = entity.scale
        restPosition = entity.position
        restBottomOffset = bottomOffset
        idleTime = 0
        idleBlend = 0
        animation = loops ? clip.repeat() : clip
        prepareRenderer()
        anchor.addChild(entity)
        playback = entity.playAnimation(loops ? clip.repeat() : clip, startsPaused: true)
        preparedURL = asset.url
        preparedDuration = asset.duration
    }

    func resume(playing: Bool) {
        guard let view else { return }
        if view.superview == nil {
            view.frame = host.bounds
            host.addSubview(view)
        }
        greetingPlaying = playing
        if idleEnabled, idleUpdate == nil {
            idleUpdate = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.updateIdle(deltaTime: event.deltaTime)
            }
        }
        if playing { playback?.resume() } else { playback?.pause() }
    }
    func suspend() {
        idleUpdate?.cancel()
        idleUpdate = nil
        greetingPlaying = false
        idleTime = 0
        idleBlend = 0
        restoreRestTransform()
        generation = UUID()
        playback?.pause()
        // Detach the render surface while inactive; there is no AR session.
        view?.removeFromSuperview()
    }
    func restart(playing: Bool) {
        guard let model, let animation else { return }
        playback?.stop()
        playback = model.playAnimation(animation, startsPaused: !playing)
    }

    func setIdleMotionEnabled(_ enabled: Bool) {
        idleEnabled = enabled
        if !enabled {
            idleUpdate?.cancel()
            idleUpdate = nil
            idleTime = 0
            idleBlend = 0
            restoreRestTransform()
        }
    }

    private func restoreRestTransform() {
        model?.scale = restScale
        model?.position = restPosition
    }

    private func updateIdle(deltaTime: TimeInterval) {
        guard let model, deltaTime.isFinite, deltaTime > 0 else { return }
        // Reuse RealityKit's existing frame callback, with no separate timer.
        guard idleEnabled, !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            idleTime = 0
            idleBlend = 0
            restoreRestTransform()
            return
        }
        let dt = min(deltaTime, 0.1)
        idleTime = (idleTime + dt).truncatingRemainder(dividingBy: 5)
        let step = Float(dt / 0.25)
        idleBlend = greetingPlaying ? max(0, idleBlend - step) : min(1, idleBlend + step)
        let expansion = SporIdleMotion.expansion(at: idleTime) * idleBlend
        model.scale = restScale * SIMD3<Float>(1 - expansion * 0.25, 1 + expansion, 1 - expansion * 0.25)
        // Compensate around the feet rather than moving the entire figure up.
        model.position = restPosition - SIMD3<Float>(0, restBottomOffset * expansion, 0)
    }
    func setBackground(_ color: UIColor) {
        host.backgroundColor = color
        backgroundColor = color
        view?.environment.background = .color(color)
    }
}
