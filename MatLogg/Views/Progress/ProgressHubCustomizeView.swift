import SwiftUI

struct ProgressHubCustomizeView: View {
    @ObservedObject var model: ProgressHubViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let visible = model.draft?.visibleAreas ?? []
        let hidden = model.draft?.order.filter { !visible.contains($0) } ?? []

        NavigationStack {
            List {
                if !visible.isEmpty {
                    Section {
                        ForEach(visible) { area in
                            areaToggle(area)
                                .accessibilityActions {
                                    if area != visible.first {
                                        Button("Flytt opp") { model.move(area, by: -1) }
                                    }
                                    if area != visible.last {
                                        Button("Flytt ned") { model.move(area, by: 1) }
                                    }
                                }
                                .moveDisabled(visible.count < 2)
                        }
                        .onMove { source, destination in
                            var reordered = visible
                            reordered.move(fromOffsets: source, toOffset: destination)
                            model.reorderVisibleAreas(reordered)
                        }
                    } header: {
                        Text("Vises i oversikten")
                    } footer: {
                        Text("I ukevisningen samles mat, skritt og trening i ett kort. Vekt vises separat.")
                    }
                }
                if !hidden.isEmpty {
                    Section("Skjulte områder") {
                        ForEach(hidden, id: \.hiddenRowID) { area in
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
            .environment(\.editMode, .constant(.active))
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

private extension ProgressHubArea {
    // A newly visible area needs a new list row with a reorder control.
    var hiddenRowID: String { "hidden-" + rawValue }
}
