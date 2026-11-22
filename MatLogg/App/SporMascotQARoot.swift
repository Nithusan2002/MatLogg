#if DEBUG && SPOR_MASCOT_QA
import SwiftUI
import Combine

struct SporMascotQARoot: View {
    @StateObject private var context = MascotQAContext()
    var body: some View {
        SporMascotPreviewView(model: context.model, controller: context.controller,
            forceReducedMotion: ProcessInfo.processInfo.arguments.contains("--spor-mascot-reduced-motion"))
    }
}

@MainActor private final class MascotQAContext: ObservableObject {
    let controller: RealityKitMascotController
    let model: SporMascotPreviewViewModel
    init() {
        let controller = RealityKitMascotController()
        self.controller = controller
        let directory = ProcessInfo.processInfo.arguments.contains("--spor-mascot-missing-asset")
            ? nil : Bundle.main.url(forResource: "SporMascotQA", withExtension: nil)
        model = SporMascotPreviewViewModel(assets: BundledMascotAssetRepository(directory: directory), player: controller)
    }
}
#endif
