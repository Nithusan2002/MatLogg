import SwiftUI
import UIKit

struct LoggView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var savedMealsViewModel: SavedMealsViewModel
    @Environment(\.matLoggTabBarScrollMargin) private var tabBarScrollMargin
    @State private var selectedDate: Date = Date()
    @State private var searchText = ""
    @State private var showSearch = false
    @FocusState private var searchFocused: Bool
    @State private var mealFilter: String?
    @State private var showAddActions = false
    @State private var showScanCamera = false
    @State private var activeSheet: AddSheet?
    @State private var editingLog: FoodLog?
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var savedMealSource: SavedMealCreationSource?

    init(initialDate: Date = Date(), initialMeal: String? = "frokost") {
        _selectedDate = State(initialValue: initialDate)
        _mealFilter = State(initialValue: initialMeal)
    }
    
    enum AddSheet: Identifiable {
        case raw
        case manual
        
        var id: String {
            switch self {
            case .raw: return "raw"
            case .manual: return "manual"
            }
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            logList
        }
            .overlay(alignment: .bottom) {
                if let id = logViewModel.deletionReceiptID {
                    LogToastView(
                        id: id,
                        title: logViewModel.deletedLogCount == 1 ? "Varen er slettet" : "\(logViewModel.deletedLogCount) varer er slettet",
                        isUndoing: logViewModel.isDeletingOrRestoring,
                        onUndo: { performDeletionUndo() },
                        onDismiss: { logViewModel.dismissDeletionReceipt() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, tabBarScrollMargin)
                } else if let payload = receiptPayload {
                    LogToastView(
                        payload: payload,
                        isUndoing: isUndoingReceipt,
                        onUndo: { undoLogging(payload) },
                        onDismiss: { dismissReceipt() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, tabBarScrollMargin)
                    .transition(.logToast)
                }
            }
            .navigationTitle("Måltider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSearch.toggle()
                        searchFocused = showSearch
                        if !showSearch { searchText = "" }
                    } label: {
                        Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .tint(AppColors.ink)
                    .accessibilityLabel(showSearch ? "Lukk søk" : mealFilter == nil ? "Søk i denne dagen" : "Søk i dette måltidet")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(mealFilter == nil ? "Velg frokost" : "Se hele dagen", systemImage: "list.bullet") {
                            mealFilter = mealFilter == nil ? "frokost" : nil
                        }
                        if let mealFilter, !logViewModel.logs(for: mealFilter).isEmpty {
                            Button("Lagre som måltid", systemImage: "square.stack.3d.up") {
                                savedMealSource = SavedMealCreationSource(mealType: mealFilter, logs: logViewModel.logs(for: mealFilter))
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
                            .font(AppTypography.bodyEmphasis)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .tint(AppColors.ink)
                    .accessibilityLabel("Flere valg for måltider")
                }
            }
            .confirmationDialog("Legg til", isPresented: $showAddActions) {
                Button("Skann") { showScanCamera = true }
                Button("Søk / Råvarer") { activeSheet = .raw }
                Button("Legg til manuelt") { activeSheet = .manual }
                if canCopyFromYesterday {
                    Button("Kopier hele dagen fra i går") {
                        Task {
                            await copyLogsFromYesterday()
                            await loadSelectedSummary()
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .raw:
                    RawMaterialsSearchView { payload in
                        receiptPayload = payload
                        Task { await loadSelectedSummary() }
                    }
                        .environmentObject(appState)
                case .manual:
                    ManualAddView(onOpenRawMaterials: {
                        activeSheet = nil
                        activeSheet = .raw
                    })
                    .environmentObject(appState)
                }
            }
            .fullScreenCover(isPresented: $showScanCamera) {
                CameraView(
                    onLogComplete: { _ in
                        Task { await loadSelectedSummary() }
                    },
                    onSearch: { activeSheet = .raw }
                )
            }
            .sheet(item: $editingLog) { log in
                EditLogView(
                    log: log,
                    productName: logViewModel.selectedProductNames[log.productId] ?? "Rediger logging",
                    onSave: { amountG, mealType in
                    Task {
                        guard let userId = authViewModel.currentUser?.id else { return }
                        if await logViewModel.updateLog(log, amountG: amountG, mealType: mealType, userId: userId) {
                            await appState.refreshSyncStatus()
                        } else {
                            appState.errorMessage = logViewModel.errorMessage
                        }
                        await loadSelectedSummary()
                    }
                })
                .environmentObject(appState)
            }
            .sheet(item: $savedMealSource) { source in
                SaveMealFromLogsView(source: source)
            }
            .onChange(of: authViewModel.currentUser?.id) { _, _ in
                logViewModel.dismissDeletionReceipt()
            }
            .onDisappear { logViewModel.dismissDeletionReceipt() }
            .task(id: "\(authViewModel.currentUser?.id.uuidString ?? "local")-\(selectedDate.timeIntervalSince1970)") {
                appState.logSelectedDate = selectedDate
                await loadSelectedSummary()
            }
            .onChange(of: mealFilter) { _, newValue in
                if let newValue { appState.selectedMealType = newValue }
            }
            .onChange(of: appState.logSelectedDate) { _, newValue in
                if !Calendar.current.isDate(selectedDate, inSameDayAs: newValue) {
                    selectedDate = newValue
                }
            }
            .onChange(of: logViewModel.mutationRevision) { _, _ in
                Task { await loadSelectedSummary() }
            }
    }

    private func dismissReceipt() {
        if UIAccessibility.isReduceMotionEnabled {
            receiptPayload = nil
        } else {
            withAnimation(.smooth(duration: 0.32)) { receiptPayload = nil }
        }
    }

    private func undoLogging(_ payload: ReceiptPayload) {
        guard !isUndoingReceipt, let userId = authViewModel.currentUser?.id else { return }
        isUndoingReceipt = true
        Task {
            let succeeded = await logViewModel.undoLatestLog(
                productId: payload.product.id,
                mealType: payload.mealType,
                amountG: Float(payload.amountG),
                userId: userId,
                date: payload.loggedDate
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
    
    private var mealTitle: String {
        guard let mealFilter else { return "Hele dagen" }
        return LogSummaryService.title(for: mealFilter)
    }

    private var logList: some View {
        let groups = groupedLogs
        let logs = logViewModel.logs(for: mealFilter)
        let totals = logViewModel.nutrition(for: mealFilter)
        let loading = logViewModel.isSummaryLoading || logViewModel.selectedSummary.map { !Calendar.current.isDate($0.date, inSameDayAs: selectedDate) } != false
        return List {
            Section {
                DayNavigationBar(selection: $selectedDate)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MealPresentation.all) { meal in
                            MealChip(title: meal.title, isSelected: mealFilter == meal.key) {
                                mealFilter = meal.key
                            }
                            .accessibilityIdentifier("meal-room-select-\(meal.key)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(mealFilter == nil ? "Velg frokost" : "Se hele dagen") {
                    mealFilter = mealFilter == nil ? "frokost" : nil
                }
                .font(AppTypography.secondaryEmphasis)
                .foregroundStyle(AppColors.action)
                .frame(minHeight: 44)
                .accessibilityIdentifier("meal-room-all")
                if showSearch {
                    TextField(mealFilter == nil ? "Søk i denne dagen" : "Søk i dette måltidet", text: $searchText)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .padding(12)
                        .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("meal-room-search")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(mealTitle)
                        .font(AppTypography.hero)
                        .foregroundStyle(AppColors.deepInk)
                    if !loading {
                        Text("\(logs.count) \(logs.count == 1 ? "matvare" : "matvarer") registrert")
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .padding(.vertical, 8)
                if !loading {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mealFilter == nil ? "Hele dagen" : "Dette måltidet")
                            .font(AppTypography.captionEmphasis)
                        Text("\(NutritionDisplay.wholeCalories(totals.calories)) kcal")
                            .font(AppTypography.title)
                        Text("Protein \(NutritionDisplay.wholeGrams(totals.protein)) g · Karbohydrat \(NutritionDisplay.wholeGrams(totals.carbs)) g · Fett \(NutritionDisplay.wholeGrams(totals.fat)) g")
                            .font(AppTypography.secondary)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("meal-room-totals")
                }
            }
            .listRowBackground(AppColors.background)
            .listRowSeparator(.hidden)

            if loading {
                ProgressView("Henter måltider …")
                    .frame(maxWidth: .infinity, minHeight: 96)
                    .listRowBackground(AppColors.background)
            } else {
                ForEach(groups, id: \.mealType) { group in
                    Section {
                        ForEach(group.logs) { log in
                            LogRowView(
                                log: log,
                                productName: logViewModel.selectedProductNames[log.productId] ?? "Ukjent produkt",
                                compact: true,
                                mealRoom: true,
                                imageURL: logViewModel.mealProductImageURLs[log.productId],
                                imageData: logViewModel.mealProductImageData[log.productId],
                                onEdit: { editingLog = log },
                                onMove: { editingLog = log },
                                onDelete: { deleteLog(log) }
                            )
                            .accessibilityIdentifier("meal-room-row-\(log.id.uuidString)")
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            .listRowBackground(AppColors.surface)
                            .listRowSeparatorTint(AppColors.separator)
                        }
                    } header: {
                        if mealFilter == nil {
                            HStack {
                                Text(LogSummaryService.title(for: group.mealType))
                                Spacer()
                                Button("Legg til") { beginAdding(to: group.mealType) }
                                    .frame(minHeight: 44)
                                    .tint(AppColors.action)
                                Menu {
                                    Button("Lagre som måltid", systemImage: "square.stack.3d.up") {
                                        savedMealSource = SavedMealCreationSource(mealType: group.mealType, logs: logViewModel.logs(for: group.mealType))
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Flere valg for \(LogSummaryService.title(for: group.mealType))")
                            }
                        }
                    }
                }
                if groups.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(searchText.isEmpty ? "Ingen mat registrert ennå" : "Ingen treff")
                            .font(AppTypography.title)
                        Text(searchText.isEmpty ? "Legg til mat for valgt måltid og dato." : "Prøv et annet søk. Måltidets totaler inkluderer fortsatt alle varene.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                        if !searchText.isEmpty {
                            Button("Nullstill søket") { searchText = "" }.frame(minHeight: 44)
                        }
                    }
                    .listRowBackground(AppColors.background)
                    .listRowSeparator(.hidden)
                }
            }
            Section {
                PrimaryButton(title: "Legg til mat", systemImage: "plus") {
                    beginAdding(to: mealFilter ?? appState.selectedMealType)
                }
                .accessibilityIdentifier("meal-room-add")

            }
            .listRowBackground(AppColors.background)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
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

    private var groupedLogs: [(mealType: String, logs: [FoodLog])] {
        let logs = logViewModel.selectedSummary?.logs ?? []
        return LogSummaryService.groupedLogs(
            logs: logs,
            searchText: searchText,
            mealFilter: mealFilter,
            productNameLookup: { logViewModel.selectedProductNames[$0] ?? "" }
        )
    }
    
    private var hasLogs: Bool {
        !(logViewModel.selectedSummary?.logs.isEmpty ?? true)
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
        if let mealFilter { appState.selectedMealType = mealFilter }
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
                    .foregroundColor(AppColors.action)
                }
            }
        }
    }
}

struct EditLogView: View {
    @Environment(\.dismiss) private var dismiss
    let log: FoodLog
    let productName: String
    let onSave: (Float, String) -> Void
    
    @State private var amountText: String = ""
    @State private var selectedMealType: String = "lunsj"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MatLoggSheetHeader(title: productName) { dismiss() }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Endre mengden eller flytt varen til et annet måltid.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)

                        CardContainer {
                            VStack(alignment: .leading, spacing: 16) {
                                AmountInputRow(
                                    gramsText: $amountText,
                                    unit: log.resolvedAmountUnit.rawValue
                                )

                                Divider().overlay(AppColors.separator)

                                Text("Måltid")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.ink)

                                mealButtons
                            }
                        }

                        if !amountText.isEmpty, parsedAmount == nil {
                            Text("Mengden må være større enn 0 og høyst 10 000 \(log.resolvedAmountUnit.rawValue).")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.action)
                                .accessibilityLabel("Feil: Mengden må være større enn 0 og høyst 10 000 \(log.resolvedAmountUnit.spokenName).")
                        }
                    }
                    .padding(16)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(title: "Lagre endringer") {
                    guard let amount = parsedAmount else { return }
                    onSave(amount, selectedMealType)
                    dismiss()
                }
                .disabled(parsedAmount == nil)
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
                        .foregroundColor(AppColors.action)
                }
            }
            .onAppear {
                amountText = formatAmount(log.amountG)
                selectedMealType = log.mealType
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder private var mealButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(MealPresentation.all) { option in
                    mealButton(option)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(MealPresentation.all) { option in
                    mealButton(option)
                }
            }
        }
    }

    private func mealButton(_ option: MealPresentation) -> some View {
        MealChip(
            title: option.title,
            isSelected: selectedMealType == option.key,
            action: { selectedMealType = option.key }
        )
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Flytt til \(option.title)")
    }

    private var parsedAmount: Float? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Float(normalized), value.isFinite, value > 0, value <= 10_000 else { return nil }
        return value
    }

    private func formatAmount(_ amount: Float) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "nb_NO")))
    }
}
