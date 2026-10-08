import SwiftUI

struct LoggingDraftBanner: View {
    @EnvironmentObject private var model: FoodLoggingDraftViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showingFlow = false
    @State private var confirmsDiscard = false
    var onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let draft = model.draft {
                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Du har en uferdig registrering").font(AppTypography.bodyEmphasis)
                        if !draft.input.name.isEmpty { Text(draft.input.name).font(AppTypography.body) }
                        Text(draft.date, format: .dateTime.day().month().year()).font(AppTypography.caption)
                        Button("Fortsett") { showingFlow = true }
                            .frame(minHeight: 44).disabled(model.isBusy).accessibilityIdentifier("logging-draft-continue")
                        Button("Forkast", role: .destructive) { confirmsDiscard = true }
                            .frame(minHeight: 44).disabled(model.isBusy).accessibilityIdentifier("logging-draft-discard")
                    }
                }
            }
            if let error = model.errorMessage {
                ErrorMessageView(error)
                Button("Prøv igjen") {
                    Task {
                        if model.isLoaded { await model.flush() }
                        else { await model.load(owner: auth.currentUser?.id) }
                    }
                }.frame(minHeight: 44)
            }
        }
        .task(id: auth.currentUser?.id) { await model.load(owner: auth.currentUser?.id) }
        .fullScreenCover(isPresented: $showingFlow) {
            RecoverableManualLoggingView(resuming: true, onLogComplete: onLogComplete)
        }
        .confirmationDialog("Forkaste den uferdige registreringen?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Forkast", role: .destructive) { Task { await model.discard() } }
            Button("Avbryt", role: .cancel) {}
        }
    }
}

/// Shared entry point for manual logging, including first log and unknown barcode.
struct RecoverableManualLoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @EnvironmentObject private var model: FoodLoggingDraftViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logs: LogViewModel
    @State private var ready = false
    @State private var confirmsDiscard = false
    var barcode: String? = nil
    var resuming = false
    let onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        Group {
            if ready, model.draft?.step == .product, let manual = model.manualModel {
                VStack(spacing: 0) {
                    if let error = model.errorMessage {
                        ErrorMessageView(error).padding()
                        Button("Prøv igjen") { Task { await model.flush() } }.frame(minHeight: 44)
                    }
                    ManualProductForm(viewModel: manual, barcode: model.draft?.barcode,
                                      onSaved: { _ in }, keepsFlowOpen: true, onClose: { await model.flush() })
                }
            } else if ready, model.draft?.step == .amount, let amount = model.amountModel {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(model.draft?.product?.name ?? "Mengde").font(AppTypography.title)
                            Text("Registreringen gjelder \(model.draft?.date.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(AppTypography.body)
                            DatePicker("Dato", selection: Binding(get: { model.draft?.date ?? Date() }, set: model.setDate), displayedComponents: .date)
                            Picker("Måltid", selection: Binding(get: { model.draft?.mealType ?? "frokost" }, set: model.setMealType)) {
                                ForEach(["frokost", "lunsj", "middag", "snacks"], id: \.self) {
                                    Text(LogSummaryService.title(for: $0)).tag($0)
                                }
                            }
                            PortionAmountInput(model: amount)
                            if let error = model.errorMessage { ErrorMessageView(error) }
                            PrimaryButton(title: model.isBusy ? "Lagrer …" : "Legg til", systemImage: "plus") {
                                Task {
                                    if let receipt = await model.complete() {
                                        logs.didPersistExternalLog()
                                        await appState.refreshSyncStatus()
                                        onLogComplete(receipt)
                                        dismiss()
                                    }
                                }
                            }
                            .disabled(!amount.isValid || model.isBusy)
                            .accessibilityIdentifier("logging-draft-save")
                            Text("Utkastet lagres bare på denne iPhonen.").font(AppTypography.caption)
                        }.padding(16)
                        .disabled(model.isBusy)
                    }
                    .background(AppColors.background.ignoresSafeArea())
                    .navigationTitle("Velg mengde")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button { Task { if await model.flush() { dismiss() } } } label: {
                                Image(systemName: "xmark")
                                    .font(AppTypography.body)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Lukk")
                            .disabled(model.isBusy)
                        }
                    }
                }
            } else {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 16) {
                        if model.draft != nil {
                            Text("Du har en uferdig registrering").font(AppTypography.sectionTitle)
                            Button("Fortsett") { ready = true }.frame(minHeight: 44)
                            Button("Forkast", role: .destructive) { confirmsDiscard = true }.frame(minHeight: 44)
                        } else if (!model.isLoaded || model.isBusy) && model.errorMessage == nil {
                            ProgressView("Åpner registrering …")
                        }
                        if let error = model.errorMessage {
                            ErrorMessageView(error)
                            Button("Prøv igjen") { Task { await prepare() } }.frame(minHeight: 44)
                        }
                    }.padding()
                    .navigationTitle("Manuell registrering")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Lukk") { dismiss() } } }
                }
            }
        }
        .interactiveDismissDisabled()
        .task { await prepare() }
        .onChange(of: phase) { _, value in
            if value != .active && ready { Task { await model.flush() } }
        }
        .onChange(of: auth.currentUser?.id) { _, _ in dismiss() }
        .confirmationDialog("Forkaste den uferdige registreringen?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button("Forkast", role: .destructive) {
                Task { if await model.discard() { await prepare() } }
            }
            Button("Avbryt", role: .cancel) {}
        }
    }

    private func prepare() async {
        await model.load(owner: auth.currentUser?.id)
        if model.draft != nil { if resuming { ready = true }; return }
        ready = await model.start(barcode: barcode,
                                  mealType: appState.logSelectedMeal ?? appState.selectedMealType,
                                  date: appState.logSelectedDate)
    }
}
