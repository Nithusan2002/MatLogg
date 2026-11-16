import SwiftUI

struct HealthHistoryExportView: View {
    @StateObject private var model: HealthHistoryExportViewModel
    @EnvironmentObject private var integration: HealthIntegrationViewModel
    @State private var confirmShare = false

    init(model: HealthHistoryExportViewModel) { _model = StateObject(wrappedValue: model) }

    var body: some View {
        Form {
            Section {
                Picker("Periode", selection: $model.period) {
                    ForEach(HealthHistoryExportViewModel.Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                if model.period == .custom {
                    DatePicker("Fra", selection: $model.startDate, in: ...Date(), displayedComponents: .date)
                    DatePicker("Til og med", selection: $model.endDate, in: ...Date(), displayedComponents: .date)
                }
                Toggle("Matregistreringer", isOn: $model.nutrition).disabled(!model.settings.shareNutrition)
                Toggle("Vekt registrert i Spor Mat", isOn: $model.weight).disabled(!model.settings.shareWeight)
                Button("Vis oversikt") { Task { await model.prepare() } }
                    .disabled(!model.canPreview)
                    .accessibilityIdentifier("health-history-preview")
            } footer: {
                if let message = model.validationMessage { Text(message) }
                Text("Bare datagrupper du har aktivert deling for kan velges. Registreringene i Spor Mat endres ikke.")
            }
            .disabled(model.isBusy)
            .listRowBackground(AppColors.surface)

            if let preview = model.preview {
                Section("Dette deler du") {
                    Text("\(preview.request.start.formatted(date: .abbreviated, time: .omitted)) – \(model.endDateForPreview(preview).formatted(date: .abbreviated, time: .omitted))")
                    Text(preview.registrationSummary)
                    Text("\(preview.sampleCount) Helse-verdier. \(preview.unchangedCount) er allerede overført eller ligger i kø uten endringer.")
                    if preview.sampleCount == 0 { Text("Ingen registreringer i denne perioden.") }
                    Button("Del til Apple Helse") { confirmShare = true }
                        .disabled(model.isBusy || preview.sampleCount == 0)
                        .accessibilityIdentifier("health-history-share")
                }
                .listRowBackground(AppColors.surface)
            }
            if let result = model.result {
                Section("Resultat") {
                    Text("\(result.transferred) Helse-verdier er overført, inkludert verdier som var delt fra før.")
                    if result.pending > 0 {
                        Text("\(result.pending) venter på overføring. Kontroller tilgang i Helse. Du kan prøve igjen fra Del til Apple Helse.")
                    }
                }
                .accessibilityIdentifier("health-history-result")
                .listRowBackground(AppColors.surface)
            }
            if model.isBusy { ProgressView("Behandler historikk …") }
            if let error = model.errorMessage { Text(error).accessibilityIdentifier("health-history-error") }
        }
        .font(AppTypography.body)
        .foregroundStyle(AppColors.ink)
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        .background(AppColors.background.ignoresSafeArea())
        .tint(AppColors.action)
        .navigationTitle("Del tidligere registreringer")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .onChange(of: integration.owner) { _, owner in
            confirmShare = false
            model.selectOwner(owner)
            Task { await model.load() }
        }
        .confirmationDialog("Dele denne historikken til Apple Helse?", isPresented: $confirmShare, titleVisibility: .visible) {
            Button("Del til Apple Helse") { Task { await model.share() } }
                .accessibilityIdentifier("health-history-confirm")
        } message: {
            Text("Opprinnelige datoer og verdier beholdes. Gjentatt overføring bruker samme identiteter for å unngå duplikater. Dette endrer ikke matloggen.")
        }
    }
}
