import Foundation
import RealityKit
import Testing
import UIKit
@testable import MatLogg

@MainActor struct MascotRendererLifecycleTests {
    @Test func inactivePresentationDoesNotCreateRenderer() {
        var creations = 0
        let controller = RealityKitMascotController(makeRenderer: {
            creations += 1
            return ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        })
        controller.setBackground(.systemBackground)
        controller.suspend()
        controller.resume(playing: false)
        controller.restart(playing: false)
        #expect(creations == 0)
        #expect(controller.host.subviews.isEmpty)
    }

    @Test func missingAssetDoesNotCreateRenderer() async {
        var creations = 0
        let controller = RealityKitMascotController(makeRenderer: {
            creations += 1
            return ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        })
        do {
            try await controller.prepare(MascotAsset(
                url: URL(fileURLWithPath: "/missing-spor-qa-asset.usdz"), duration: 6))
            Issue.record("Missing model should fail preparation")
        } catch {
            #expect(creations == 0)
            #expect(controller.host.subviews.isEmpty)
        }
    }
}
