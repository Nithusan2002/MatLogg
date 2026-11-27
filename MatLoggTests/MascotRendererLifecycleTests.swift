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
        controller.setIdleMotionEnabled(true)
        controller.setIdleMotionEnabled(false)
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

    @Test func durationMismatchDoesNotCreateRenderer() async throws {
        let url = try #require(Bundle.main.url(forResource: "spor-greeting", withExtension: "usdz"))
        var creations = 0
        let controller = RealityKitMascotController(makeRenderer: {
            creations += 1
            return ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        })
        do {
            try await controller.prepare(MascotAsset(url: url, duration: 5))
            Issue.record("Mismatched animation duration should be rejected")
        } catch {
            #expect(error is MascotAssetError)
            #expect(creations == 0)
        }
    }

    @Test func validRendererDetachesAndReusesWithCorrectSize() async throws {
        let url = try #require(Bundle.main.url(forResource: "spor-greeting", withExtension: "usdz"))
        var renderer: ARView?
        var creations = 0
        let controller = RealityKitMascotController(loops: false, makeRenderer: {
            creations += 1
            let result = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
            renderer = result
            return result
        })
        try await controller.prepare(MascotAsset(url: url, duration: 6))
        let surface = try #require(renderer)
        #expect(surface.superview == nil)
        controller.host.frame = CGRect(x: 0, y: 0, width: 180, height: 180)
        controller.resume(playing: true)
        #expect(surface.superview === controller.host)
        #expect(surface.frame == controller.host.bounds)
        let anchor = try #require(surface.scene.anchors.first)
        let imported = try #require(Array(anchor.children).last)
        try await controller.prepare(MascotAsset(url: url, duration: 6))
        #expect(Array(anchor.children).last === imported,
                "Repeated waves must retain the imported entity and its presentation")
        controller.suspend()
        #expect(surface.superview == nil)
        controller.host.frame = CGRect(x: 0, y: 0, width: 260, height: 220)
        controller.resume(playing: false)
        #expect(surface.superview === controller.host)
        #expect(surface.frame == controller.host.bounds)
        #expect(creations == 1)
        controller.suspend()
    }
}
