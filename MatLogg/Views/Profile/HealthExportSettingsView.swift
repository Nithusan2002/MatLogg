import SwiftUI

struct HealthExportSettingsView: View {
    @EnvironmentObject private var model: HealthIntegrationViewModel
    @State private var confirmCleanup = false

    var body: some View {
        Form {
            Section {
                Toggle("Kalorier og makroer", isOn: $model.choices.shareNutrition)
                    .accessibilityIdentifier("health-share-nutrition")
                Toggle("Vekt registrert i Spor Mat", isOn: $model.choices.shareWeight)
                    .accessibilityIdentifier("health-share-weight")
                Button("Lagre valg") { Task { await model.connect() } }
                    .disabled(!(model.choices.shareNutrition || model.choices.shareWeight))
                    .accessibilityIdentifier("health-connect")
            } footer: {
                Text("Nye og endrede registreringer deles. Eldre historikk deles ikke automatisk. Du styrer tilgang i Helse, også for andre apper som kan lese dataene.")
            }
            .disabled(model.isBusy || !model.isAvailable)
            .listRowBackground(AppColors.surface)

            Section {
                Text(model.exportStatus(kinds: HealthDataKind.allCases))
                if model.settings.isConnected {
                    Button("Prøv igjen") { Task { await model.refresh() } }
                    Button("Stopp deling", role: .destructive) { Task { await model.disconnect() } }
                        .accessibilityIdentifier("health-disconnect")
                }
                if !model.records.isEmpty {
                    Button("Slett delte data fra Helse", role: .destructive) { confirmCleanup = true }
                        .accessibilityIdentifier("health-delete-exports")
                }
                if model.isBusy { ProgressView("Oppdaterer Apple Helse …") }
                if let error = model.errorMessage { Text(error).accessibilityIdentifier("health-error") }
                if let message = model.completionMessage { Text(message) }
                if !model.isAvailable { Text("Eksport er ikke tilgjengelig i denne økten eller på denne enheten.") }
            }
            header: { Text("Overføring") }
            footer: {
                if model.settings.isConnected {
                    Text("Stopp deling beholder data som allerede ligger i Helse.")
                }
            }
            .disabled(model.isBusy || !model.isAvailable)
            .listRowBackground(AppColors.surface)
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.ink)
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .navigationTitle("Del til Apple Helse")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Slette delte data fra Helse?", isPresented: $confirmCleanup, titleVisibility: .visible) {
            Button("Slett fra Helse", role: .destructive) { Task { await model.deleteExports() } }
        } message: {
            Text("Deling stoppes. Bare data denne Spor Mat-profilen har delt slettes fra Helse. Registreringer i Spor Mat og data fra andre apper beholdes.")
        }
    }
}
