#if DEBUG && SPOR_MASCOT_QA
import SwiftUI
import RealityKit
import UIKit

struct SporMascotPreviewView: View {
    @ObservedObject var model: SporMascotPreviewViewModel
    let controller: RealityKitMascotController
    var forceReducedMotion = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var effectiveReducedMotion: Bool { forceReducedMotion || reducedMotion }
    private var playbackLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Text("Spor – forhåndsvisning").font(AppTypography.title)
                    .accessibilityAddTraits(.isHeader)
                Text("Intern designprøve").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                ZStack {
                    MascotSceneView(controller: controller, dark: colorScheme == .dark)
                        .opacity(model.phase == .ready ? 1 : 0)
                    if model.phase == .loading || model.phase == .idle {
                        ProgressView("Laster Spor …")
                    } else if model.phase == .failed {
                        VStack(spacing: 8) {
                            MascotPoster(image: controller.poster)
                                .frame(maxWidth: 96, maxHeight: 96)
                            Text("Kunne ikke laste Spor").font(AppTypography.secondary)
                        }
                    }
                }
                .frame(width: model.size.points, height: model.size.points)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 24))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .accessibilityHidden(true)
                Text(status).font(AppTypography.secondary)
                    .accessibilityIdentifier("mascot-status")
                if model.phase == .failed {
                    Button("Prøv igjen") { Task { await model.loadSelection() } }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("mascot-retry")
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Animasjon").font(AppTypography.sectionTitle)
                    Picker("Animasjon", selection: Binding(get: { model.clip }, set: model.select)) {
                        ForEach(MascotClip.allCases) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).frame(minHeight: 44).accessibilityIdentifier("mascot-clip")
                    playbackLayout {
                        Button(model.isPlaying ? "Pause" : "Spill av", systemImage: model.isPlaying ? "pause.fill" : "play.fill") {
                            model.togglePlayback()
                        }.accessibilityIdentifier("mascot-playback")
                        Button("Start på nytt", systemImage: "arrow.counterclockwise") { model.restart() }
                            .accessibilityIdentifier("mascot-restart")
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.phase != .ready)
                    .controlSize(.large)
                    settingsControls
                }
                if effectiveReducedMotion {
                    Text("Redusert bevegelse er på. Trykk Spill av for å prøve animasjonen.")
                        .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(AppColors.background)
        .foregroundStyle(AppColors.ink)
        .preferredColorScheme(model.appearance.colorScheme)
        .task(id: model.clip) {
            model.setReducedMotion(effectiveReducedMotion)
            model.setActive(scenePhase == .active)
            await model.loadSelection()
        }
        .onChange(of: effectiveReducedMotion) { _, value in model.setReducedMotion(value) }
        .onChange(of: scenePhase) { _, value in model.setActive(value == .active) }
        .onDisappear { model.setActive(false) }
    }

    private var status: String {
        switch model.phase {
        case .idle, .loading: "Laster Spor …"
        case .failed: "Kunne ikke laste Spor"
        case .ready: "\(model.clip.title) · \(model.isPlaying ? "Spiller" : "Pauset")"
        }
    }

    @ViewBuilder private var settingsControls: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) {
                Text("Størrelse")
                sizePicker.fixedSize()
                Text("Utseende")
                appearancePicker.fixedSize()
            }
        } else {
            LabeledContent("Størrelse") { sizePicker }
            LabeledContent("Utseende") { appearancePicker }
        }
    }
    private var sizePicker: some View {
        Picker("Størrelse", selection: $model.size) {
            ForEach(SporMascotPreviewViewModel.Size.allCases) { Text($0.title).tag($0) }
        }.labelsHidden().accessibilityLabel("Størrelse").accessibilityIdentifier("mascot-size")
    }
    private var appearancePicker: some View {
        Picker("Utseende", selection: $model.appearance) {
            ForEach(SporMascotPreviewViewModel.Appearance.allCases) { Text($0.title).tag($0) }
        }.labelsHidden().accessibilityLabel("Utseende").accessibilityIdentifier("mascot-appearance")
    }
}

private struct MascotSceneView: UIViewRepresentable {
    let controller: RealityKitMascotController
    let dark: Bool
    func makeUIView(context: Context) -> UIView { controller.host }
    func updateUIView(_ view: UIView, context: Context) {
        controller.setBackground(UIColor(AppColors.surface).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light)))
    }
}

private struct MascotPoster: View {
    let image: UIImage?
    var body: some View {
        if let image { Image(uiImage: image).resizable().scaledToFit() }
        else { Image(systemName: "figure.stand").font(.largeTitle) }
    }
}
#endif
