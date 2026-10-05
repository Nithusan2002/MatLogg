import SwiftUI

struct MorningCheckInView: View {
    @ObservedObject var viewModel: MorningCheckInViewModel
    let userId: UUID?
    let date: Date
    @State private var showWeightPicker = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let completed = viewModel.status == "completed"
        let title = completed ? "Sjekket inn i dag" : "Sjekk inn"
        Group {
            if userId != nil, Calendar.current.isDateInToday(date), viewModel.status != "skipped" {
                Button { viewModel.begin() } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView("Henter innsjekk …")
                        } else if dynamicTypeSize.isAccessibilitySize {
                            Text(completed ? "✓ \(title)" : title)
                        } else {
                            Label(title, systemImage: completed ? "checkmark.circle.fill" : "checkmark.circle")
                        }
                    }
                    .font(AppTypography.bodyEmphasis)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundColor(AppColors.actionText)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
                }
                .disabled(viewModel.isLoading || viewModel.isSaving)
                .accessibilityLabel(viewModel.isLoading ? "Henter innsjekk" : title)
                .accessibilityHint(viewModel.status == "completed" ? "Åpner dagens innsjekk for redigering" : "Åpner valgfri vektregistrering")
                .accessibilityIdentifier("morning-check-in-open")
            }
        }
        .task(id: "\(userId?.uuidString ?? "none")-\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)") {
            await viewModel.load(userId: userId, date: date)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await viewModel.load(userId: userId, date: date) } }
        }
        .sheet(isPresented: $viewModel.isPresented, onDismiss: {
            Task { await viewModel.load(userId: userId, date: date) }
        }) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Dagens vekt er valgfri. Du kan sjekke inn uten å veie deg.")
                            .foregroundStyle(AppColors.textSecondary)
                        Text("Registrer vekt (kg)").font(AppTypography.bodyEmphasis)
                        Button { showWeightPicker = true } label: {
                            HStack(spacing: 12) {
                                Text(viewModel.weightText.isEmpty ? "Velg vekt (valgfritt)" : viewModel.weightText + " kg")
                                    .foregroundStyle(viewModel.weightText.isEmpty ? AppColors.textSecondary : AppColors.ink)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(AppTypography.captionEmphasis)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .accessibilityHidden(true)
                            }
                            .padding(12)
                            .frame(minHeight: 48)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.controlBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dagens vekt i kilogram, valgfritt")
                        .accessibilityValue(viewModel.weightText.isEmpty ? "Ikke oppgitt" : viewModel.weightText)
                        .accessibilityHint("Åpner tallskala og direkte inntasting.")
                        .accessibilityIdentifier("morning-check-in-weight")
                        Text("Vekten lagres i vekthistorikken under Utvikling. Målene dine endres ikke. Et tomt felt sletter ikke en tidligere registrering.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        if let error = viewModel.errorMessage {
                            ErrorMessageView(error)
                                .accessibilityIdentifier("morning-check-in-error")
                        }
                        PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Ferdig", systemImage: "checkmark") {
                            Task { await viewModel.finish() }
                        }
                        .accessibilityIdentifier("morning-check-in-save")
                        Button("Hopp over i dag") { viewModel.skip() }.frame(minHeight: 44)
                    }
                    .font(AppTypography.body)
                    .padding(20)
                    .disabled(viewModel.isSaving)
                }
                .background(AppColors.background)
                .navigationTitle("Morgensjekk")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Avbryt") { viewModel.isPresented = false }.disabled(viewModel.isSaving)
                    }
                }
            }
            .sheet(isPresented: $showWeightPicker) {
                MeasurementPickerSheet(
                    measurement: .weight,
                    initialText: viewModel.weightText,
                    explanation: "Vekten lagres i vekthistorikken når du trykker Ferdig i Sjekk inn. Målene dine endres ikke."
                ) { value in
                    viewModel.weightText = value
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }
}
