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
                Button("Lagre valg og be om tilgang") { Task { await model.connect() } }
                    .disabled(!(model.choices.shareNutrition || model.choices.shareWeight))
                    .accessibilityIdentifier("health-connect")
            } footer: {
                Text("Bare nye eller endrede registreringer deles. Tidligere historikk overføres ikke automatisk. Tilgang styres i Helse; disse valgene bekrefter ikke at tilgang er gitt. Data i Helse kan være tilgjengelig for andre apper du har gitt tilgang.")
            }
            .disabled(model.isBusy || !model.isAvailable)
            .listRowBackground(AppColors.surface)

            Section("Overføring") {
                Text(model.exportStatus(kinds: HealthDataKind.allCases))
                if model.settings.isConnected {
                    Button("Prøv overføring nå") { Task { await model.refresh() } }
                    Button("Stopp all deling", role: .destructive) { Task { await model.disconnect() } }
                        .accessibilityIdentifier("health-disconnect")
                    Text("Stopp beholder data som allerede er delt med Helse.")
                        .font(AppTypography.caption)
                }
                if !model.records.isEmpty {
                    Button("Slett denne profilens delte data fra Helse", role: .destructive) { confirmCleanup = true }
                        .accessibilityIdentifier("health-delete-exports")
                }
                if model.isBusy { ProgressView("Oppdaterer Apple Helse …") }
                if let error = model.errorMessage { Text(error).accessibilityIdentifier("health-error") }
                if let message = model.completionMessage { Text(message) }
                if !model.isAvailable { Text("Eksport er ikke tilgjengelig i denne økten eller på denne enheten.") }
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
