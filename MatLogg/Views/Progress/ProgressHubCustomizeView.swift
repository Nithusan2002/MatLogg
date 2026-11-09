import SwiftUI

struct ProgressHubCustomizeView: View {
    @ObservedObject var model: ProgressHubViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            List {
                if model.draft != nil {
                    Section("Vises i oversikten") {
                        ForEach(ProgressHubLayout.standardOrder) { area in
                            areaToggle(area)
                        }
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

    private func areaToggle(_ area: ProgressHubArea) -> some View {
        Toggle(isOn: Binding(
            get: { model.draft?.visible.contains(area) ?? false },
            set: { model.setVisible(area, isVisible: $0) }
        )) {
            Label(area.title, systemImage: area.symbol)
                .font(AppTypography.bodyEmphasis)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("progress-hub-toggle-" + area.rawValue)
        .listRowBackground(AppColors.surface)
    }
}
