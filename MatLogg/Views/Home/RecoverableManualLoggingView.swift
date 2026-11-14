import SwiftUI

struct LoggingDraftBanner: View {
    enum Presentation { case card, row }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var model: FoodLoggingDraftViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showingFlow = false
    @State private var confirmsDiscard = false
    var continueTitle = "Fortsett"
    var presentation: Presentation = .card
    var onLogComplete: (ReceiptPayload) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let draft = model.draft {
                if presentation == .row {
                    HStack(spacing: 12) {
                        Button { showingFlow = true } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Fortsett registreringen")
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundStyle(AppColors.deepInk)
                                    let name = (draft.product?.name ?? draft.input.name).trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !name.isEmpty {
                                        Text(name).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                                    }
                                    (Text(LogSummaryService.title(for: draft.mealType)) + Text(" · ")
                                     + Text(draft.date, format: .dateTime.day().month(.abbreviated).year()))
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "chevron.right")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Åpner den uferdige registreringen med lagrede verdier")
                        .accessibilityIdentifier("logging-draft-continue")
                        Menu {
                            Button("Forkast registreringen", role: .destructive) { confirmsDiscard = true }
                                .accessibilityIdentifier("logging-draft-discard")
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(AppColors.textSecondary)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Valg for uferdig registrering")
                        .accessibilityIdentifier("logging-draft-options")
                    }
                    .disabled(model.isBusy)
                } else {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Uferdig registrering")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(AppColors.deepInk)
                                .accessibilityAddTraits(.isHeader)
                            let name = (draft.product?.name ?? draft.input.name).trimmingCharacters(in: .whitespacesAndNewlines)
                            if !name.isEmpty {
                                Text(name).font(AppTypography.body).foregroundStyle(AppColors.deepInk)
                            }
                            (Text(LogSummaryService.title(for: draft.mealType)) + Text(" · ")
                             + Text(draft.date, format: .dateTime.day().month(.abbreviated).year()))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            let layout = dynamicTypeSize >= .xxxLarge
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                            layout {
                                PrimaryButton(title: continueTitle, height: 44) { showingFlow = true }
                                    .disabled(model.isBusy)
                                    .accessibilityHint("Åpner den uferdige registreringen med lagrede verdier")
                                    .accessibilityIdentifier("logging-draft-continue")
                                Button("Forkast", role: .destructive) { confirmsDiscard = true }
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .disabled(model.isBusy)
                                    .accessibilityIdentifier("logging-draft-discard")
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
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
                }.frame(minHeight: 44).disabled(model.isBusy)
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
