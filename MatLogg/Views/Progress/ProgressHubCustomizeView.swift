import SwiftUI

struct ProgressHubCustomizeView: View {
    @ObservedObject var model: ProgressHubViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.draft?.order ?? []) { area in
                        VStack(alignment: .leading, spacing: 8) {
                            let layout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                : AnyLayout(HStackLayout(spacing: 12))
                            layout {
                                Label(area.title, systemImage: area.symbol)
                                    .font(AppTypography.bodyEmphasis)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                Toggle(area.title, isOn: Binding(
                                    get: { model.draft?.visible.contains(area) ?? false },
                                    set: { model.setVisible(area, isVisible: $0) }
                                ))
                                .labelsHidden()
                                .frame(minHeight: 44)
                                .accessibilityLabel(area.title)
                                .accessibilityIdentifier("progress-hub-toggle-" + area.rawValue)
                            }
                            let moveLayout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                : AnyLayout(HStackLayout(spacing: 12))
                            moveLayout {
                                Button { model.move(area, by: -1) } label: {
                                    Label("Opp", systemImage: "arrow.up")
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(minHeight: 44)
                                }
                                .accessibilityLabel("Flytt \(area.title) opp")
                                .disabled(model.draft?.order.first == area)
                                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                                Button { model.move(area, by: 1) } label: {
                                    Label("Ned", systemImage: "arrow.down")
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(minHeight: 44)
                                }
                                .accessibilityLabel("Flytt \(area.title) ned")
                                .disabled(model.draft?.order.last == area)
                            }
                            .buttonStyle(.borderless)
                            .font(AppTypography.secondaryEmphasis)
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppColors.surface)
                    }
                } header: {
                    Text("Dine områder")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Velg hvilke kort som vises her, og flytt dem i ønsket rekkefølge.")
                        Text("I Uke samles mat, skritt og treningsøkter i ett kort. Vekt vises før eller etter ukekortet.")
                        Text("Du styrer hvilke data MatLogg henter under Innstillinger → Apple Helse.")
                    }
                }
                Section {
                    Button("Gjenopprett standard") { model.restoreDefault() }
                        .frame(minHeight: 44)
                        .listRowBackground(AppColors.surface)
                }
                if let error = model.errorMessage {
                    Section { ErrorMessageView(error).listRowBackground(AppColors.surface) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .tint(AppColors.action)
            .navigationTitle(dynamicTypeSize.isAccessibilitySize ? "Tilpass" : "Tilpass oversikten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { model.cancelEditing(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lagre") { if model.save() { dismiss() } }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("progress-hub-save")
                }
            }
        }
        .tint(AppColors.action)
    }
}
