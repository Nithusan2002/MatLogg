import SwiftUI
import UIKit

struct LoggView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    @EnvironmentObject var savedMealsViewModel: SavedMealsViewModel
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var yesterdaySummary: DailySummary?
    @State private var searchText = ""
    @State private var mealFilter: String?
    @State private var showFilterSheet = false
    @State private var showAddActions = false
    @State private var activeSheet: AddSheet?
    @State private var editingLog: FoodLog?
    @State private var showDeleteConfirm = false
    @State private var logPendingDelete: FoodLog?
    @State private var receiptPayload: ReceiptPayload?
    @State private var isUndoingReceipt = false
    @State private var savedMealSource: SavedMealCreationSource?

    init(initialDate: Date = Date(), initialMealFilter: String? = nil) {
        _selectedDate = State(initialValue: initialDate)
        _mealFilter = State(initialValue: initialMealFilter)
    }
    
    enum AddSheet: Identifiable {
        case scan
        case raw
        case manual
        
        var id: String {
            switch self {
            case .scan: return "scan"
            case .raw: return "raw"
            case .manual: return "manual"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()
                
                logList
            }
            .overlay(alignment: .bottom) {
                if let payload = receiptPayload {
                    LogToastView(
                        payload: payload,
                        isUndoing: isUndoingReceipt,
                        onUndo: { undoLogging(payload) },
                        onDismiss: { dismissReceipt() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.logToast)
                }
            }
            .navigationTitle("Logg")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showFilterSheet = true }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .disabled(!hasLogs)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddActions = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("Legg til", isPresented: $showAddActions) {
                Button("Skann") { activeSheet = .scan }
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
                case .scan:
                    CameraView(onLogComplete: { _ in
                        Task { await loadSelectedSummary() }
                    })
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
            .sheet(item: $editingLog) { log in
                EditLogView(log: log, onSave: { amountG, mealType in
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
            .alert("Slett logging?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) {
                    if let log = logPendingDelete {
                        Task {
                            guard let userId = authViewModel.currentUser?.id else { return }
                            if await logViewModel.deleteLog(log, userId: userId) {
                                await appState.refreshSyncStatus()
                            } else {
                                appState.errorMessage = logViewModel.errorMessage
                            }
                            await loadSelectedSummary()
                        }
                    }
                }
                Button("Avbryt", role: .cancel) {}
            }
            .onAppear {
                if let meal = appState.logSelectedMeal, mealFilter == nil {
                    mealFilter = meal
                    appState.logSelectedMeal = nil
                }
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
        let baseList = List {
            Section {
                DayNavigationBar(selection: $selectedDate)
                .padding(.vertical, 4)
            }
            .listRowBackground(AppColors.background)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
            
            if hasLogs {
                Section {
                    Button(action: {
                        mealFilter = nil
                        searchText = ""
                    }) {
                        CardContainer {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Dagsoppsummering")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text("\(selectedSummary?.logs.count ?? 0) innslag")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                
                                if !preferencesViewModel.safeModeHideCalories {
                                    HStack(spacing: 12) {
                                        Text("\(selectedSummary?.totalCalories ?? 0) kcal")
                                        Text("P \(Int(selectedSummary?.totalProtein ?? 0)) g")
                                        Text("K \(Int(selectedSummary?.totalCarbs ?? 0)) g")
                                        Text("F \(Int(selectedSummary?.totalFat ?? 0)) g")
                                    }
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppColors.background)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            
            if canCopyFromYesterday {
                Section {
                    Button("Kopier fra i går") {
                        Task {
                            await copyLogsFromYesterday()
                            await loadSelectedSummary()
                        }
                    }
                    .foregroundColor(AppColors.brand)
                }
            }
            
            ForEach(groupedLogs, id: \.mealType) { group in
                Section {
                    ForEach(group.logs) { log in
                        LogRowView(
                            log: log,
                            showCalories: !preferencesViewModel.safeModeHideCalories,
                            onEdit: {
                                editingLog = log
                            },
                            onMove: {
                                editingLog = log
                            },
                            onDelete: {
                                logPendingDelete = log
                                showDeleteConfirm = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(AppColors.background)
                    }
                } header: {
                    HStack {
                        Text(LogSummaryService.title(for: group.mealType))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
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
            
            if groupedLogs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 42))
                        .foregroundColor(AppColors.textSecondary)
                    Text("Ingen logging denne dagen")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    Text("Legg til for denne dagen eller gå til i dag.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Button(action: { showAddActions = true }) {
                        Text("Legg til for denne dagen")
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
        
        baseList.searchable(text: $searchText, prompt: hasLogs ? "Søk i dagens logg" : "Søk i logg")
    }
    
    private var groupedLogs: [(mealType: String, logs: [FoodLog])] {
        let logs = selectedSummary?.logs ?? []
        return LogSummaryService.groupedLogs(
            logs: logs,
            searchText: searchText,
            mealFilter: mealFilter,
            productNameLookup: { productViewModel.product(id: $0)?.name ?? "" }
        )
    }
    
    private var hasLogs: Bool {
        !(selectedSummary?.logs.isEmpty ?? true)
    }
    
    private var canCopyFromYesterday: Bool {
        isTodaySelected && !(yesterdaySummary?.logs.isEmpty ?? true)
    }
    
    private var isTodaySelected: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
    
    private func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func loadSelectedSummary() async {
        guard let userId = authViewModel.currentUser?.id else {
            selectedSummary = nil
            yesterdaySummary = nil
            return
        }
        selectedSummary = await logViewModel.fetchSummary(userId: userId, date: selectedDate)
        if Calendar.current.isDateInToday(selectedDate) {
            yesterdaySummary = await logViewModel.fetchSummary(userId: userId, date: yesterdayDate())
        } else {
            yesterdaySummary = nil
        }
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
    
    private let options: [(label: String, value: String?)] = [
        ("Alle måltider", nil),
        ("Frokost", "frokost"),
        ("Lunsj", "lunsj"),
        ("Middag", "middag"),
        ("Snacks", "snacks")
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.label) { option in
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
    @EnvironmentObject private var productViewModel: ProductViewModel
    let log: FoodLog
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
                                AmountInputRow(gramsText: $amountText)

                                Divider().overlay(AppColors.separator)

                                Text("Måltid")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.ink)

                                mealButtons
                            }
                        }

                        if !amountText.isEmpty, parsedAmount == nil {
                            Text("Mengden må være større enn 0 og høyst 10 000 g.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.action)
                                .accessibilityLabel("Feil: Mengden må være større enn 0 og høyst 10 000 gram.")
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

    private var productName: String {
        productViewModel.product(id: log.productId)?.name ?? "Rediger logging"
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
