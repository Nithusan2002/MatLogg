import SwiftUI

struct AppleHealthSettingsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var steps: StepCountViewModel
    @EnvironmentObject private var weight: HealthWeightViewModel

    var body: some View {
        Form {
            Section {
                sourceToggle("Skritt", kind: .steps, model: steps)
                sourceToggle("Vekt", kind: .weight, model: weight)
            } header: {
                Text("Hent fra Apple Helse")
            } footer: {
                Text("Valgene gjelder denne MatLogg-profilen. MatLogg viser målingene i Utvikling og lagrer dem bare midlertidig. Du styrer lesetilgangen i Helse.")
            }
            .listRowBackground(AppColors.surface)
        }
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("Apple Helse")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var isAuthorizing: Bool { steps.isAuthorizing || weight.isAuthorizing }

    private func sourceToggle<Snapshot: HealthReadSnapshot>(
        _ title: String, kind: HealthReadKind, model: HealthReadViewModel<Snapshot>
    ) -> some View {
        let owner = auth.currentUser?.id
        let matchesOwner = owner != nil && model.owner == owner
        return VStack(alignment: .leading, spacing: 6) {
            Toggle(title, isOn: Binding(
                get: { matchesOwner && model.isEnabled },
                set: { enabled in
                    guard matchesOwner, model.owner == owner else { return }
                    if enabled {
                        Task {
                            guard model.owner == owner, !isAuthorizing else { return }
                            await model.connect()
                        }
                    } else {
                        model.disconnect()
                    }
                }
            ))
            .disabled(!matchesOwner || isAuthorizing || model.availability != .available)
            .accessibilityIdentifier(kind == .steps ? "apple-health-steps-toggle" : "apple-health-weight-toggle")
            if matchesOwner {
                if model.isAuthorizing {
                    ProgressView("Ber om tilgang …")
                } else if let error = model.connectionError {
                    Text(error).foregroundStyle(AppColors.textSecondary)
                } else if model.availability == .demo {
                    Text("Tilgjengelig fra din egen profil.").foregroundStyle(AppColors.textSecondary)
                } else if model.availability == .unavailable {
                    Text("Apple Helse er ikke tilgjengelig på denne enheten.").foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .font(AppTypography.body)
    }
}

struct AppleHealthSettingsShortcut: View {
    let action: () -> Void

    var body: some View {
        Button("Åpne Apple Helse-innstillinger", action: action)
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.actionText)
            .frame(minHeight: 44)
            .accessibilityIdentifier("apple-health-settings-shortcut")
    }
}

struct AppleHealthSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            AppleHealthSettingsView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ferdig") { dismiss() }
                            .accessibilityIdentifier("apple-health-settings-done")
                    }
                }
        }
    }
}
