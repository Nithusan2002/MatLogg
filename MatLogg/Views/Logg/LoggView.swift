import SwiftUI
import UIKit

struct LoggView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel
    var initialDate = Date()
    var initialMeal: String?

    var body: some View {
        LoggContent(appState: appState, logViewModel: logViewModel, authViewModel: authViewModel,
                    savedMealsViewModel: savedMealsViewModel, initialDate: initialDate, initialMeal: initialMeal)
    }
}

private struct LoggContent: View {
    let appState: AppState
    let logViewModel: LogViewModel
    let authViewModel: AuthViewModel
    let savedMealsViewModel: SavedMealsViewModel
    @Environment(\.matLoggTabBarScrollMargin) private var tabBarScrollMargin
    @State private var selectedDate: Date = Date()
    @StateObject private var screen: LogScreenViewModel
    @State private var isPullRefreshing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pendingMealScroll: String?
    @State private var showAddActions = false
    @State private var editingLog: FoodLog?
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var savedMealSource: SavedMealCreationSource?
    @State private var showBatchDeletion = false

    init(appState: AppState, logViewModel: LogViewModel, authViewModel: AuthViewModel,
         savedMealsViewModel: SavedMealsViewModel, initialDate: Date, initialMeal: String?) {
        self.appState = appState
        self.logViewModel = logViewModel
        self.authViewModel = authViewModel
        self.savedMealsViewModel = savedMealsViewModel
        _selectedDate = State(initialValue: initialDate)
        _pendingMealScroll = State(initialValue: initialMeal)
        _screen = StateObject(wrappedValue: LogScreenViewModel(logs: logViewModel, appState: appState,
            auth: authViewModel, savedMeals: savedMealsViewModel, includesEmptyMeals: true))
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            logList
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: screen.isSelecting)
        .preference(key: MatLoggDiarySelectionKey.self, value: screen.isSelecting
            ? MatLoggDiarySelectionPresentation(contextID: ObjectIdentifier(screen),
                count: screen.selectedLogIDs.count, canSave: screen.canSaveSelection,
                isBusy: screen.isDeletingOrRestoring, onSave: saveSelection,
                onDelete: { showBatchDeletion = true })
            : nil)
        .overlay(alignment: .bottom) { if !screen.isSelecting { receiptOverlay } }
        .confirmationDialog("Slette \(screen.selectedLogIDs.count) registreringer?", isPresented: $showBatchDeletion, titleVisibility: .visible) {
            Button("Slett", role: .destructive) { deleteSelection() }
            Button("Avbryt", role: .cancel) {}
        }
        .navigationTitle("Måltider")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationToolbar }
        .sheet(isPresented: $showAddActions) { loggingSheet }
        .sheet(item: $editingLog) { log in logEditor(for: log) }
        .sheet(item: $savedMealSource) { source in
            SaveMealFromLogsView(source: source) { screen.endSelection() }
        }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            logViewModel.dismissDeletionReceipt()
            screen.endSelection()
            savedMealSource = nil
            showBatchDeletion = false
        }
        .onDisappear {
            logViewModel.dismissDeletionReceipt()
            screen.endSelection()
        }
        .onChange(of: selectedDate) { _, _ in
            screen.endSelection()
            showBatchDeletion = false
        }
        .task(id: "\(authViewModel.currentUser?.id.uuidString ?? "local")-\(selectedDate.timeIntervalSince1970)") {
            appState.logSelectedDate = selectedDate
            await loadSelectedSummary()
        }
        .onChange(of: appState.logSelectedDate) { _, newValue in
            if !Calendar.current.isDate(selectedDate, inSameDayAs: newValue) {
                selectedDate = newValue
            }
        }
        .onChange(of: logViewModel.mutationRevision) { _, _ in
            Task { await loadSelectedSummary() }
        }
        .onChange(of: savedMealsViewModel.mutationRevision) { _, _ in
            Task { await loadSelectedSummary() }
        }
    }

    private var receiptOverlay: some View {
        LogReceiptOverlay(logs: logViewModel, payload: receiptPayload, isUndoing: isUndoingReceipt,
            onDeletionUndo: performDeletionUndo, onLoggingUndo: { if let receiptPayload { undoLogging(receiptPayload) } },
            onLoggingDismiss: dismissReceipt)
            .padding(.horizontal, 16)
            .padding(.bottom, tabBarScrollMargin)
    }

    @ToolbarContentBuilder private var navigationToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(screen.isSelecting ? "Avbryt" : "Velg") {
                if screen.isSelecting { screen.endSelection() }
                else { screen.beginSelection() }
            }
            .disabled(screen.isDeletingOrRestoring || (!screen.isSelecting && (screen.isLoading || !hasLogs)))
            .accessibilityIdentifier("meal-room-select")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            if !screen.isSelecting {
                Menu {
                    Menu("Lagre som måltid", systemImage: "square.stack.3d.up") {
                        ForEach(MealPresentation.all) { meal in
                            Button(meal.title) {
                                savedMealSource = SavedMealCreationSource(mealType: meal.key, logs: logViewModel.logs(for: meal.key))
                            }
                            .disabled(logViewModel.logs(for: meal.key).isEmpty)
                        }
                    }
                    Button("Gå til i dag", systemImage: "calendar") {
                        selectedDate = Date()
                    }
                    if canCopyFromYesterday {
                        Section {
                            Button("Kopier hele dagen fra i går", systemImage: "doc.on.doc") {
                                Task {
                                    await copyLogsFromYesterday()
                                    await loadSelectedSummary()
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .tint(AppColors.ink)
                .accessibilityLabel("Flere valg for dagsloggen")
                .accessibilityIdentifier("meal-room-reuse")
            }
        }
    }

    private func saveSelection() {
        savedMealSource = SavedMealCreationSource(mealType: screen.selectionMealType,
            logs: screen.selectedLogs, allowsMealTypeChoice: screen.selectionSpansMeals)
    }

    private func deleteSelection() {
        let logs = screen.selectedLogs
        guard let userId = authViewModel.currentUser?.id else { return }
        Task {
            if await logViewModel.deleteBatchWithUndo(logs, userId: userId) {
                screen.endSelection()
                dismissReceipt()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage
            }
            await loadSelectedSummary()
        }
    }

    private var loggingSheet: some View {
        LoggingFlowView(
            onLogComplete: { payload in
                receiptPayload = payload
                Task { await loadSelectedSummary() }
            },
            onSavedMealLogComplete: {
                Task { await loadSelectedSummary() }
            }
        )
        .presentationDetents([.fraction(0.66), .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(36)
    }

    private func logEditor(for log: FoodLog) -> some View {
        EditLogView(
            log: log,
            productName: screen.names[log.productId] ?? "Ukjent matvare",
            brand: screen.brands[log.productId],
            imageURL: screen.imageURLs[log.productId],
            imageData: screen.imageData[log.productId],
            onSave: { amountG, mealType, portion in
                    guard let userId = authViewModel.currentUser?.id else { return false }
                    let success = await logViewModel.updateLog(log, amountG: amountG, mealType: mealType, userId: userId, portionSelection: portion, clearPortion: portion == nil)
                    if success {
                        await appState.refreshSyncStatus()
                    } else {
                        appState.errorMessage = logViewModel.errorMessage
                    }
                    await loadSelectedSummary()
                    return success
            }
        )
        .environmentObject(appState)
    }

    private func dismissReceipt() {
        if UIAccessibility.isReduceMotionEnabled {
            receiptPayload = nil
        } else {
            withAnimation(.smooth(duration: 0.32)) { receiptPayload = nil }
        }
    }

    private func undoLogging(_ payload: ReceiptPayload) {
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id,
              payload.ownerID == nil || payload.ownerID == userId else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate,
                logID: payload.logID
            )
            if succeeded {
                dismissReceipt()
                await loadSelectedSummary()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage ?? "Kunne ikke angre loggingen."
            }
            isUndoingReceipt = false
        }
    }
    
    private var logList: some View {
        let groups = groupedLogs
        let logs = screen.presentation.mealLogs
        let hasCurrentSummary = screen.summary.map { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } == true
        let loading = screen.isLoading || !hasCurrentSummary
        return ScrollViewReader { proxy in
            List {
                Section {
                    DayNavigationBar(selection: $selectedDate)
                        .disabled(screen.isDeletingOrRestoring)
                    if screen.isSelecting {
                        HStack {
                            Button(screen.isGroupSelected() ? "Fjern alle valg" : "Velg alle") {
                                screen.toggleGroup()
                            }
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("meal-room-select-all")
                            Spacer()
                        }
                        .disabled(screen.isDeletingOrRestoring)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hele dagen")
                            .font(AppTypography.hero)
                            .foregroundStyle(AppColors.deepInk)
                        if hasCurrentSummary {
                            Text("\(logs.count) \(logs.count == 1 ? "matvare" : "matvarer") registrert")
                                .font(AppTypography.secondary)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(.vertical, 8)
                    if hasCurrentSummary, let summary = screen.summary {
                        StatusSummaryContent(summary: summary, goal: nil)
                            .padding(20)
                            .matLoggCardSurface(fill: AppColors.energySurfaceGradient, cornerRadius: 24, shadowEnabled: false, borderEnabled: false)
                            .accessibilityIdentifier("meal-room-totals")
                    }
                }
                .listRowBackground(AppColors.background)
                .listRowSeparator(.hidden)

                if loading && (!isPullRefreshing || !hasCurrentSummary) {
                    ProgressView("Henter måltider …")
                        .frame(maxWidth: .infinity, minHeight: 96)
                        .listRowBackground(AppColors.background)
                }
                if hasCurrentSummary {
                    ForEach(groups, id: \.mealType) { group in
                        Section {
                            HStack {
                                Text(LogSummaryService.title(for: group.mealType))
                                    .font(AppTypography.sectionTitle)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityIdentifier("meal-room-heading-\(group.mealType)")
                                Spacer()
                                if screen.isSelecting {
                                    Button(screen.isGroupSelected(group.mealType) ? "Fjern valg" : "Velg alle") {
                                        screen.toggleGroup(group.mealType)
                                    }
                                    .frame(minHeight: 44)
                                    .disabled(group.logs.isEmpty || screen.isDeletingOrRestoring)
                                    .accessibilityLabel("Velg eller fjern valg for \(LogSummaryService.title(for: group.mealType))")
                                } else {
                                    Button("Legg til") { beginAdding(to: group.mealType) }
                                        .accessibilityIdentifier("meal-room-add-\(group.mealType)")
                                        .frame(minHeight: 44)
                                        .tint(AppColors.action)
                                    Menu {
                                        Button("Lagre som måltid", systemImage: "square.stack.3d.up") {
                                            savedMealSource = SavedMealCreationSource(mealType: group.mealType, logs: logViewModel.logs(for: group.mealType))
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                    }
                                    .disabled(group.logs.isEmpty)
                                    .accessibilityLabel("Flere valg for \(LogSummaryService.title(for: group.mealType))")
                                }
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 32, bottom: 0, trailing: 32))
                            .listRowBackground(mealCardBackground(top: true))
                            .listRowSeparator(.hidden)
                            if group.logs.isEmpty {
                                Text("Ingen mat registrert")
                                    .font(AppTypography.secondary)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.bottom, 16)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 32, bottom: 0, trailing: 32))
                                    .listRowBackground(mealCardBackground(bottom: true))
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(group.logs) { log in
                                LogRowView(
                                    log: log,
                                    productName: screen.names[log.productId] ?? "Ukjent produkt",
                                    compact: true,
                                    mealRoom: true,
                                    imageURL: screen.imageURLs[log.productId],
                                    imageData: screen.imageData[log.productId],
                                    isSelected: screen.selectedLogIDs.contains(log.id),
                                    onSelect: screen.isSelecting ? { screen.toggleSelection(log.id) } : nil,
                                    onEdit: screen.isSelecting ? nil : { editingLog = log },
                                    onMove: screen.isSelecting ? nil : { editingLog = log },
                                    onDelete: screen.isSelecting ? nil : { deleteLog(log) }
                                )
                                .disabled(screen.isDeletingOrRestoring)
                                .accessibilityIdentifier("meal-room-row-\(log.id.uuidString)")
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .padding(.bottom, log.id == group.logs.last?.id ? 6 : 0)
                                .overlay(alignment: .bottom) {
                                    if log.id != group.logs.last?.id {
                                        Rectangle()
                                            .fill(AppColors.separator)
                                            .frame(height: 0.5)
                                            .padding(.horizontal, 16)
                                    }
                                }
                                .listRowBackground(mealCardBackground(bottom: log.id == group.logs.last?.id))
                                .listRowSeparator(.hidden)
                            }
                            Color.clear
                                .frame(height: 16)
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(AppColors.background)
                                .listRowSeparator(.hidden)
                        }
                        .listSectionSeparator(.hidden)
                        .id(group.mealType)
                    }
                    if groups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingen mat registrert ennå")
                                .font(AppTypography.title)
                            Text("Legg til mat for valgt dato.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .listRowBackground(AppColors.background)
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .refreshable {
                isPullRefreshing = true
                defer { isPullRefreshing = false }
                await logViewModel.loadSelectedSummary(userId: authViewModel.currentUser?.id, date: selectedDate)
            }
            .listStyle(.plain)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .matLoggTabBarScrollClearance()
            .task(id: "\(hasCurrentSummary)-\(pendingMealScroll ?? "")") {
                guard hasCurrentSummary, let meal = pendingMealScroll,
                      groups.contains(where: { $0.mealType == meal }) else { return }
                appState.selectedMealType = meal
                if reduceMotion {
                    proxy.scrollTo(meal, anchor: .top)
                } else {
                    withAnimation { proxy.scrollTo(meal, anchor: .top) }
                }
                pendingMealScroll = nil
            }
        }
    }


    private func mealCardBackground(top: Bool = false, bottom: Bool = false) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: top ? 24 : 0,
            bottomLeadingRadius: bottom ? 24 : 0,
            bottomTrailingRadius: bottom ? 24 : 0,
            topTrailingRadius: top ? 24 : 0,
            style: .continuous
        )
        .fill(AppColors.surface)
        .padding(.horizontal, 16)
        .background(AppColors.background)
    }

    private func beginAdding(to meal: String) {
        appState.selectedMealType = meal
        appState.logSelectedDate = selectedDate
        showAddActions = true
    }

    private func deleteLog(_ log: FoodLog) {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await logViewModel.deleteWithUndo(log, userId: userId) {
                dismissReceipt()
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage
            }
            await loadSelectedSummary()
        }
    }

    private func performDeletionUndo() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await logViewModel.undoDeletion(userId: userId) {
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = logViewModel.errorMessage
            }
            await loadSelectedSummary()
        }
    }

    private var groupedLogs: [(mealType: String, logs: [FoodLog])] { screen.presentation.groups }

    private var hasLogs: Bool {
        !(screen.summary?.logs.isEmpty ?? true)
    }
    
    private var canCopyFromYesterday: Bool {
        isTodaySelected && !(logViewModel.yesterdaySummary?.logs.isEmpty ?? true)
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func loadSelectedSummary() async {
        await logViewModel.loadSelectedSummary(
            userId: authViewModel.currentUser?.id,
            date: selectedDate
        )
    }

    private func copyLogsFromYesterday() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        if await logViewModel.copyLogs(from: yesterdayDate(), to: selectedDate, userId: userId) {
            await appState.refreshSyncStatus()
        } else {
            appState.errorMessage = logViewModel.errorMessage
        }
    }
}

struct LoggFilterSheet: View {
    @Binding var selected: String?
    @Environment(\.dismiss) private var dismiss
    
    private struct Option: Identifiable {
        let id: String
        let label: String
        let value: String?
    }

    private let options: [Option] = [
        Option(id: "all", label: "Alle måltider", value: nil),
        Option(id: "frokost", label: "Frokost", value: "frokost"),
        Option(id: "lunsj", label: "Lunsj", value: "lunsj"),
        Option(id: "middag", label: "Middag", value: "middag"),
        Option(id: "snacks", label: "Kveldsmat", value: "snacks")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(options) { option in
                    Button(action: {
                        selected = option.value
                        dismiss()
                    }) {
                        HStack {
                            Text(option.label)
                                .foregroundColor(AppColors.ink)
                            Spacer()
                            if selected == option.value {
                                Image(systemName: "checkmark")
                                    .foregroundColor(AppColors.brand)
                            }
                        }
                    }
                }
                .listRowBackground(AppColors.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .tint(AppColors.action)
            .navigationTitle("Filter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Nullstill") {
                        selected = nil
                    }
                    .foregroundColor(AppColors.actionText)
                }
            }
        }
    }
}

struct EditLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let log: FoodLog
    let productName: String
    let brand: String?
    let imageURL: URL?
    let imageData: Data?
    let onSave: (Float, String, PortionSelection?) async -> Bool
    
    @StateObject private var model: EditLogViewModel

    init(log: FoodLog, productName: String, brand: String? = nil, imageURL: URL? = nil, imageData: Data? = nil,
         onSave: @escaping (Float, String, PortionSelection?) async -> Bool) {
        self.log = log
        self.productName = productName
        self.brand = brand
        self.imageURL = imageURL
        self.imageData = imageData
        self.onSave = onSave
        _model = StateObject(wrappedValue: EditLogViewModel(log: log))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MatLoggSheetHeader(title: "Rediger logging", isCloseDisabled: model.isSaving) { dismiss() }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            ProductThumbnailView(url: imageURL, localData: imageData, imagePadding: 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(productName)
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(AppTypography.secondary)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                Text("Logget \(log.loggedDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(AppTypography.secondary)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        CardContainer {
                            VStack(alignment: .leading, spacing: 16) {
                                PortionAmountInput(model: model.amount)
                                    .disabled(model.isSaving)

                                nutritionSummary

                                Divider().overlay(AppColors.separator)

                                Text("Måltid")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.ink)

                                mealButtons
                            }
                        }

                    }
                    .padding(16)
                }
                .accessibilityIdentifier("log-editor-scroll")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let error = model.error {
                        ErrorMessageView(error).font(AppTypography.caption)
                    }
                    PrimaryButton(title: model.isSaving ? "Lagrer …" : "Lagre endringer") {
                        Task { if await model.save(onSave) { dismiss() } }
                    }
                    .disabled(!model.canSave)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.background)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.actionText)
                }
            }

        }
        .interactiveDismissDisabled(model.isSaving)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var nutritionSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Næring for valgt mengde")
                .font(AppTypography.secondary)
                .foregroundStyle(AppColors.textSecondary)
            if let nutrition = model.nutrition {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 240 : 130))], spacing: 8) {
                    SummaryPill(label: "Energi", value: "\(NutritionDisplay.wholeCalories(nutrition.calories)) kcal", tintColor: AppColors.energyTint)
                    SummaryPill(label: "Proteiner", value: "\(nutrition.protein.formatted(.number.precision(.fractionLength(1)))) g", tintColor: AppColors.macroProteinTint)
                    SummaryPill(label: "Karbohydrater", value: "\(nutrition.carbs.formatted(.number.precision(.fractionLength(1)))) g", tintColor: AppColors.macroCarbTint)
                    SummaryPill(label: "Fett", value: "\(nutrition.fat.formatted(.number.precision(.fractionLength(1)))) g", tintColor: AppColors.macroFatTint)
                }
                Text("Beregnet fra næringsverdiene i loggingen.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Text("Næring kan ikke beregnes. Kontroller mengden og loggingens næringsgrunnlag.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder private var mealButtons: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
            spacing: 8
        ) {
            ForEach(MealPresentation.all) { option in
                mealButton(option)
            }
        }
    }

    private func mealButton(_ option: MealPresentation) -> some View {
        MealChip(
            title: option.title,
            isSelected: model.mealType == option.key,
            fillsWidth: true,
            action: { model.mealType = option.key }
        )
        .frame(maxWidth: .infinity)
        .disabled(model.isSaving)
        .accessibilityLabel("Flytt til \(option.title)")
    }

}

private struct LogReceiptOverlay: View {
    @StateObject private var viewModel: LogDeletionReceiptViewModel
    let logs: LogViewModel
    let payload: ReceiptPayload?
    let isUndoing: Bool
    let onDeletionUndo: () -> Void
    let onLoggingUndo: () -> Void
    let onLoggingDismiss: () -> Void

    init(logs: LogViewModel, payload: ReceiptPayload?, isUndoing: Bool,
         onDeletionUndo: @escaping () -> Void, onLoggingUndo: @escaping () -> Void,
         onLoggingDismiss: @escaping () -> Void) {
        self.logs = logs
        self.payload = payload
        self.isUndoing = isUndoing
        self.onDeletionUndo = onDeletionUndo
        self.onLoggingUndo = onLoggingUndo
        self.onLoggingDismiss = onLoggingDismiss
        _viewModel = StateObject(wrappedValue: LogDeletionReceiptViewModel(logs: logs))
    }

    var body: some View {
        if let id = viewModel.receipt.id {
            LogToastView(id: id,
                title: viewModel.receipt.count == 1 ? "Varen er slettet" : "\(viewModel.receipt.count) varer er slettet",
                isUndoing: viewModel.receipt.isBusy, onUndo: onDeletionUndo,
                onDismiss: { logs.dismissDeletionReceipt() })
        } else if let payload {
            LogToastView(payload: payload, isUndoing: isUndoing, onUndo: onLoggingUndo, onDismiss: onLoggingDismiss)
                .transition(.logToast)
        }
    }
}
