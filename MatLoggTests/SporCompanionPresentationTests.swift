import SwiftUI
import RealityKit
import Testing
import UIKit
@testable import MatLogg

@Suite(.serialized)
@MainActor struct SporCompanionPresentationTests {
    @Test(.enabled("Requires system Reduce Motion") {
        await MainActor.run { UIAccessibility.isReduceMotionEnabled }
    })
    func reducedMotionDoesNotRequestAnimation() async throws {
        try await verifyNoAnimation(eligible: true, phase: .active)
    }
    @Test func hiddenPresentationDoesNotRequestAnimation() async throws {
        try await verifyNoAnimation(eligible: false, phase: .active)
    }
    @Test func backgroundSceneDoesNotRequestAnimation() async throws {
        try await verifyNoAnimation(eligible: true, phase: .background)
    }

    private func verifyNoAnimation(eligible: Bool, phase: ScenePhase) async throws {
        let assets = CountingAssets()
        let store = Store()
        var rendererCreations = 0
        let controller = RealityKitMascotController(makeRenderer: {
            rendererCreations += 1
            return ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        })
        let model = SporCompanionViewModel(player: controller, assets: assets, preferences: store)
        let session = SporCompanionSession(controller: controller, model: model)
        var appeared = false
        let root = SporCompanionView(context: .home, eligible: eligible)
            .frame(width: 180, height: 180)
            .environment(\.sporCompanionFactory, SporCompanionFactory { session })
            .environment(\.scenePhase, phase)
            .onAppear { appeared = true }
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UIHostingController(rootView: root)
        window.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        window.isHidden = false
        defer { window.isHidden = true; window.rootViewController = nil }
        for _ in 0..<30 {
            if appeared { break }
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(appeared)
        try await Task.sleep(for: .milliseconds(150))
        #expect(await assets.requests == 0)
        #expect(rendererCreations == 0 && !model.isPlaying)
        #expect(store.lastHomeGreeting == nil)
    }

    private final class Store: SporGreetingStoring { var lastHomeGreeting: Date? }
    private actor CountingAssets: MascotAssetProviding {
        private(set) var requests = 0
        func asset(for clip: MascotClip) async throws -> MascotAsset {
            requests += 1
            throw MascotAssetError.unavailable
        }
    }
}
