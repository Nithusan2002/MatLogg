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
    @State private var showFilterSheet = false
    @State private var showAddActions = false
    @State private var showScanCamera = false
    @State private var activeSheet: AddSheet?
    @State private var editingLog: FoodLog?
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var savedMealSource: SavedMealCreationSource?

    init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: initialDate)
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
            .navigationTitle("Logg")
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
                    .accessibilityLabel(showSearch ? "Lukk søk" : "Søk i denne dagen")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(AppTypography.bodyEmphasis)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .tint(AppColors.ink)
                    .accessibilityLabel("Filtrer loggen")
                    .disabled(!hasLogs)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Gå til i dag", systemImage: "calendar") {
                            selectedDate = Date()
                        }
                        if canCopyFromYesterday {
                            Section {
                                Button("Kopier fra i går", systemImage: "doc.on.doc") {
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
                    .accessibilityLabel("Flere valg for dagen")
                }
            }
            .confirmationDialog("Legg til", isPresented: $showAddActions) {
                Button("Skann") { showScanCamera = true }
                Button("Søk / Råvarer") { activeSheet = .raw }
                Button("Legg til manuelt") { activeSheet = .manual }
                if canCopyFromYesterday {
                    Button("Kopier fra i går") {
                        Task {
                            await copyLogsFromYesterday()
                            await loadSelectedSummary()
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                LoggFilterSheet(selected: $mealFilter)
                    .presentationDetents([.fraction(0.32)])
                    .presentationDragIndicator(.visible)
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
            .onAppear {
                appState.logSelectedDate = selectedDate
                Task { await loadSelectedSummary() }
            }
            .onChange(of: selectedDate) { _, newValue in
                appState.logSelectedDate = newValue
                Task { await loadSelectedSummary() }
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
    
    @ViewBuilder
    private var logList: some View {
        let groups = groupedLogs
        let baseList = List {
            Section {
                DayNavigationBar(selection: $selectedDate)
                .padding(.vertical, 4)
            }
            .listRowBackground(AppColors.background)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            
            Section {
                if showSearch {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppColors.textSecondary)
                        TextField("Søk i denne dagen", text: $searchText)
                            .focused($searchFocused)
                            .submitLabel(.search)
                    }
                    .padding(12)
                    .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
                }
                if let mealFilter {
                    Button {
                        self.mealFilter = nil
                    } label: {
                        Label("\(LogSummaryService.title(for: mealFilter)) · Vis alle", systemImage: "xmark.circle.fill")
                            .font(AppTypography.bodyEmphasis)
                            .frame(minHeight: 44)
                    }
                    .tint(AppColors.action)
                    .accessibilityLabel("Fjern måltidsfilter")
                }
                if hasLogs {
                    ViewThatFits(in: .horizontal) {
                        nutritionSummary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(NutritionDisplay.wholeCalories(logViewModel.selectedSummary?.totalCalories ?? 0)) kcal")
                                .font(AppTypography.bodyEmphasis)
                            macroSummary
                        }
                    }
                    .foregroundStyle(AppColors.ink)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(AppColors.background)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)

            ForEach(groups, id: \.mealType) { group in
                Section {
                    ForEach(group.logs) { log in
                        LogRowView(
                            log: log,
                            productName: logViewModel.selectedProductNames[log.productId] ?? "Ukjent produkt",
                            compact: true,
                            onEdit: {
                                editingLog = log
                            },
                            onMove: {
                                editingLog = log
                            },
                            onDelete: {
                                deleteLog(log)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(
                            UnevenRoundedRectangle(
                                topLeadingRadius: log.id == group.logs.first?.id ? 18 : 0,
                                bottomLeadingRadius: log.id == group.logs.last?.id ? 18 : 0,
                                bottomTrailingRadius: log.id == group.logs.last?.id ? 18 : 0,
                                topTrailingRadius: log.id == group.logs.first?.id ? 18 : 0
                            )
                            .fill(AppColors.surface)
                            .padding(.horizontal, 16)
                        )
                        .listRowSeparator(log.id == group.logs.last?.id ? .hidden : .visible)
                        .listRowSeparatorTint(AppColors.separator)
                    }
                } header: {
                    HStack {
                        Text(LogSummaryService.title(for: group.mealType))
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Spacer()
                        Button("Legg til") {
                            appState.selectedMealType = group.mealType
                            showAddActions = true
                        }
                        .font(AppTypography.captionEmphasis)
                        .tint(AppColors.action)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Legg til mat i \(LogSummaryService.title(for: group.mealType))")
                        Menu {
                            Button("Lagre som måltid", systemImage: "square.stack.3d.up") {
                                savedMealSource = SavedMealCreationSource(mealType: group.mealType, logs: group.logs)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Flere valg for \(LogSummaryService.title(for: group.mealType))")
                    }
                }
            }
            
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 42))
                        .foregroundColor(AppColors.textSecondary)
                    Text(hasLogs ? "Ingen treff" : "Ingen logging denne dagen")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    Text(hasLogs ? "Prøv et annet søk eller vis alle måltider." : "Legg til for denne dagen eller gå til i dag.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Button(action: {
                        if hasLogs {
                            searchText = ""
                            mealFilter = nil
                        } else {
                            showAddActions = true
                        }
                    }) {
                        Text(hasLogs ? "Vis alle varer" : "Legg til for denne dagen")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.onVibrant)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.brand)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    if !isTodaySelected {
                        Button(action: {
                            showAddActions = false
                            selectedDate = Date()
                        }) {
                            Text("Gå til i dag")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.separator, lineWidth: 1)
                                )
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(AppColors.background)
                .listRowInsets(EdgeInsets(top: 24, leading: 16, bottom: 24, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .matLoggTabBarScrollClearance()
        
        baseList
    }
    
    private var nutritionSummary: some View {
        HStack(spacing: 12) {
            Text("\(NutritionDisplay.wholeCalories(logViewModel.selectedSummary?.totalCalories ?? 0)) kcal")
                .font(AppTypography.bodyEmphasis)
            macroSummary
        }
    }

    private var macroSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { macroValues }
            VStack(alignment: .leading, spacing: 4) { macroValues }
        }
        .font(AppTypography.caption)
        .foregroundStyle(AppColors.textSecondary)
    }

    @ViewBuilder private var macroValues: some View {
        Text("P \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalProtein ?? 0)) g")
            .accessibilityLabel("Protein \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalProtein ?? 0)) gram")
        Text("K \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalCarbs ?? 0)) g")
            .accessibilityLabel("Karbohydrat \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalCarbs ?? 0)) gram")
        Text("F \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalFat ?? 0)) g")
            .accessibilityLabel("Fett \(NutritionDisplay.wholeGrams(logViewModel.selectedSummary?.totalFat ?? 0)) gram")
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
