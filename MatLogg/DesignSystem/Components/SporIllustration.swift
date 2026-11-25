import SwiftUI
import Combine

struct SporIllustration: View {
    var body: some View {
        Image("SporNeutral")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// Dependencies are assembled at the application root. Previews remain static.
struct SporCompanionFactory {
    let make: @MainActor () -> SporCompanionSession
}
private struct SporCompanionFactoryKey: EnvironmentKey {
    static let defaultValue: SporCompanionFactory? = nil
}
extension EnvironmentValues {
    var sporCompanionFactory: SporCompanionFactory? {
        get { self[SporCompanionFactoryKey.self] }
        set { self[SporCompanionFactoryKey.self] = newValue }
    }
}

@MainActor final class SporCompanionSession: ObservableObject {
    let controller: RealityKitMascotController
    let model: SporCompanionViewModel
    init(controller: RealityKitMascotController, model: SporCompanionViewModel) {
        self.controller = controller
        self.model = model
    }
}

struct SporCompanionView: View {
    let context: SporCompanionViewModel.Context
    let eligible: Bool
    @Environment(\.sporCompanionFactory) private var factory
    var body: some View {
        if let factory {
            SporAnimatedCompanion(context: context, eligible: eligible, factory: factory)
        } else {
            SporIllustration()
        }
    }
}

private struct SporAnimatedCompanion: View {
    let context: SporCompanionViewModel.Context
    let eligible: Bool
    @StateObject private var session: SporCompanionSession
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    init(context: SporCompanionViewModel.Context, eligible: Bool, factory: SporCompanionFactory) {
        self.context = context
        self.eligible = eligible
        _session = StateObject(wrappedValue: factory.make())
    }
    var body: some View {
        SporPlaybackView(model: session.model, controller: session.controller,
                         context: context, active: eligible && phase == .active && !reduceMotion,
                         dark: colorScheme == .dark)
            .accessibilityHidden(true)
    }
}

private struct SporPlaybackView: View {
    @ObservedObject var model: SporCompanionViewModel
    let controller: RealityKitMascotController
    let context: SporCompanionViewModel.Context
    let active: Bool
    let dark: Bool
    var body: some View {
        ZStack {
            SporIllustration().opacity(model.isPlaying ? 0 : 1)
            if model.isPlaying {
                SporRenderSurface(controller: controller, dark: dark)
            }
        }
        .task(id: active) {
            if active { await model.greet(context: context) }
            else { model.stop() }
        }
        .onDisappear { model.stop() }
    }
}

private struct SporRenderSurface: UIViewRepresentable {
    let controller: RealityKitMascotController
    let dark: Bool
    func makeUIView(context: Context) -> UIView { controller.host }
    func updateUIView(_ view: UIView, context: Context) {
        controller.setBackground(UIColor(AppColors.background).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)))
    }
    static func dismantleUIView(_ view: UIView, coordinator: ()) {
        view.subviews.forEach { $0.removeFromSuperview() }
    }
}
