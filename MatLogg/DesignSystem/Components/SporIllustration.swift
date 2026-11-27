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
    var isInteractive = false
    @Environment(\.sporCompanionFactory) private var factory
    var body: some View {
        if let factory {
            SporAnimatedCompanion(context: context, eligible: eligible, isInteractive: isInteractive, factory: factory)
        } else {
            SporIllustration()
        }
    }
}

private struct SporAnimatedCompanion: View {
    let context: SporCompanionViewModel.Context
    let eligible: Bool
    let isInteractive: Bool
    @StateObject private var session: SporCompanionSession
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    init(context: SporCompanionViewModel.Context, eligible: Bool, isInteractive: Bool, factory: SporCompanionFactory) {
        self.context = context
        self.eligible = eligible
        self.isInteractive = isInteractive
        _session = StateObject(wrappedValue: factory.make())
    }
    var body: some View {
        SporPlaybackView(model: session.model, controller: session.controller,
                         context: context, active: eligible && phase == .active && !reduceMotion,
                         allowsTap: isInteractive && eligible && phase == .active,
                         dark: colorScheme == .dark)
    }
}

private struct SporPlaybackView: View {
    @ObservedObject var model: SporCompanionViewModel
    let controller: RealityKitMascotController
    let context: SporCompanionViewModel.Context
    let active: Bool
    let allowsTap: Bool
    let dark: Bool
    var body: some View {
        Group {
            if allowsTap {
                Button { model.waveOnTap() } label: {
                    artwork.contentShape(Rectangle())
                }
                .buttonStyle(SporWaveButtonStyle())
                .disabled(model.isBusy)
                .accessibilityLabel("La Spor vinke")
                .accessibilityHint("Spiller en kort hilseanimasjon")
                .accessibilityValue(model.isPlaying ? "Vinker" : model.isLoading ? "Laster" : "Klar")
                .accessibilityIdentifier("spor-wave-button")
            } else {
                artwork
            }
        }
        .task(id: active) {
            model.setIdleMotionAllowed(active && context == .home)
            if active {
                if context == .home { await model.prepareHomeRest() }
                guard !Task.isCancelled else { return }
                await model.greet(context: context)
            }
            else { model.stop() }
        }
        .onChange(of: allowsTap) { _, allowed in
            if !allowed { model.stop() }
        }
        .onDisappear { model.stop() }
    }

    private var artwork: some View {
        ZStack {
            SporIllustration().opacity(model.isReady || model.isPlaying ? 0 : 1)
            if model.isReady || model.isPlaying {
                SporRenderSurface(controller: controller, dark: dark)
            }
        }
        .accessibilityHidden(true)
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

/// Busy state disables input without fading the artwork during its animation.
private struct SporWaveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
