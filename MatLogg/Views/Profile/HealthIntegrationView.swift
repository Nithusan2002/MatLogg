import SwiftUI

struct HealthIntegrationView: View {
    @EnvironmentObject private var model: HealthIntegrationViewModel
    @State private var confirmDisconnect = false
    @State private var confirmCleanup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Logg maten én gang")
                    .font(AppTypography.title)
                Text("Del kalorier og næringsstoffer med Apple Helse, og hent vekt fra målingene du allerede har der. Du velger hva MatLogg kan overføre.")
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Del kalorier og næringsstoffer", isOn: $model.choices.shareNutrition)
                        .accessibilityIdentifier("health-share-nutrition")
                    Text("Mat registrert eller endret etter aktivering deles. Eldre matlogger overføres ikke automatisk.")
                        .font(AppTypography.caption)
                    Toggle("Hent vekt fra Helse", isOn: $model.choices.readWeight)
                        .accessibilityIdentifier("health-read-weight")
                    Text("Henter siste 90 dager ved tilkobling, deretter nye målinger. Manuell vekt i MatLogg prioriteres samme dag.")
                        .font(AppTypography.caption)
                    Toggle("Del vekt registrert i MatLogg", isOn: $model.choices.shareWeight)
                        .accessibilityIdentifier("health-share-weight")
                    Text("Nye og endrede registreringer deles. Målene dine endres ikke automatisk.")
                        .font(AppTypography.caption)
                }
                .padding(16)
                .matLoggCardSurface()
                .disabled(model.isBusy || !model.isAvailable)

                if !model.isAvailable {
                    Text("Apple Helse er ikke tilgjengelig i denne appversjonen eller på denne enheten.")
                } else {
                    Button(model.settings.isConnected ? "Oppdater valg og tilgang" : "Koble til Apple Helse") {
                        Task { await model.connect() }
                    }
                    .accessibilityIdentifier("health-connect")
                    .disabled(model.isBusy || !(model.choices.shareNutrition || model.choices.readWeight || model.choices.shareWeight))
                    Text("Valgene viser hva du ønsker å dele. Tilgangene styres i Helse, og kan endres der når som helst.")
                        .font(AppTypography.caption)
                    if model.settings.isConnected {
                        statusCard
                        Button("Oppdater nå") { Task { await model.refresh() } }
                            .accessibilityIdentifier("health-refresh")
                            .disabled(model.isBusy)
                    }
                    if model.settings.isConnected || !model.records.isEmpty {
                        Button("Koble fra Apple Helse", role: .destructive) { confirmDisconnect = true }
                            .accessibilityIdentifier("health-disconnect")
                            .disabled(model.isBusy)
                    }
                    if !model.records.isEmpty {
                        Button("Slett data MatLogg har delt med Helse", role: .destructive) { confirmCleanup = true }
                            .accessibilityIdentifier("health-delete-exports")
                            .disabled(model.isBusy)
                    }
                }
                if model.isBusy { ProgressView("Oppdaterer Apple Helse …") }
                if let error = model.errorMessage { Text(error).accessibilityIdentifier("health-error") }
                if let message = model.completionMessage { Text(message).accessibilityIdentifier("health-completion") }
                Text("Vekt hentet fra Helse lagres bare på denne iPhonen og sendes ikke til MatLoggs server. Data du deler med Helse kan brukes av andre apper du har gitt tilgang der.")
                    .font(AppTypography.caption)
            }
            .font(AppTypography.body)
            .foregroundStyle(AppColors.ink)
            .padding(20)
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .matLoggTabBarScrollClearance()
        .background(AppColors.background)
        .tint(AppColors.action)
        .navigationTitle("Apple Helse")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Koble fra Apple Helse?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Koble fra", role: .destructive) { model.disconnect() }
        } message: {
            Text("Overføring stoppes og hentet vekt fjernes fra MatLogg. Manuelle registreringer og data som allerede er delt med Helse beholdes.")
        }
        .confirmationDialog("Slette data MatLogg har delt med Helse?", isPresented: $confirmCleanup, titleVisibility: .visible) {
            Button("Slett fra Helse", role: .destructive) { Task { await model.deleteExports() } }
        } message: {
            Text("Integrasjonen kobles fra. MatLogg sletter bare egne overføringer fra denne profilen. Data i MatLogg og målinger fra andre apper beholdes.")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overføring").font(AppTypography.sectionTitle).accessibilityAddTraits(.isHeader)
            if model.settings.shareNutrition {
                Text("Kalorier og næringsstoffer")
                Text(model.exportStatus(kinds: [.energy, .protein, .carbohydrates, .fat])).font(AppTypography.caption)
            }
            if model.settings.readWeight {
                Text("Vekt fra Helse")
                if let message = model.importMessage { Text(message).font(AppTypography.caption) }
                else if let last = model.settings.lastImport {
                    Text("Sist hentet: \(last.formatted(date: .abbreviated, time: .shortened))").font(AppTypography.caption)
                } else { Text("Ingen vekt hentet ennå.").font(AppTypography.caption) }
            }
            if model.settings.shareWeight {
                Text("Vekt til Helse")
                Text(model.exportStatus(kinds: [.weight])).font(AppTypography.caption)
            }
        }
        .padding(16)
        .matLoggCardSurface()
        .accessibilityElement(children: .contain)
    }
}
