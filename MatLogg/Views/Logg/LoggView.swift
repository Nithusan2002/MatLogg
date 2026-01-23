import SwiftUI

struct LoggView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDate: Date = Date()
    @State private var selectedSummary: DailySummary?
    @State private var yesterdaySummary: DailySummary?
    @State private var showDatePicker = false
    @State private var searchText = ""
    @State private var mealFilter: String?
    @State private var showFilterSheet = false
    @State private var showAddActions = false
    @State private var activeSheet: AddSheet?
    @State private var editingLog: FoodLog?
    @State private var showDeleteConfirm = false
    @State private var logPendingDelete: FoodLog?
    
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
                            await appState.copyLogs(from: yesterdayDate(), to: selectedDate)
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
                    RawMaterialsSearchView()
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
                        await appState.updateLog(log, amountG: amountG, mealType: mealType)
                        await loadSelectedSummary()
                    }
                })
                .environmentObject(appState)
            }
            .alert("Slett logging?", isPresented: $showDeleteConfirm) {
                Button("Slett", role: .destructive) {
                    if let log = logPendingDelete {
                        Task {
                            await appState.deleteLog(log)
                            await loadSelectedSummary()
                        }
                    }
                }
                Button("Avbryt", role: .cancel) {}
            }
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack(spacing: 16) {
                        Text("Velg dato")
                            .font(AppTypography.title)
                            .foregroundColor(AppColors.ink)
                        
                        DatePicker(
                            "Velg dato",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                    }
                    .padding(16)
                    .background(AppColors.background.ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Ferdig") { showDatePicker = false }
                                .foregroundColor(AppColors.brand)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                selectedDate = appState.logSelectedDate
                if let meal = appState.logSelectedMeal {
                    mealFilter = meal
                    appState.logSelectedMeal = nil
                }
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
        }
    }
    
    @ViewBuilder
    private var logList: some View {
        let baseList = List {
            Section {
                HStack {
                    Button(action: { shiftSelectedDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .frame(width: 44, height: 44)
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: { showDatePicker = true }) {
                        HStack(spacing: 6) {
                            Text(dayTitle)
                                .font(AppTypography.bodyEmphasis)
                            Image(systemName: "calendar")
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: { shiftSelectedDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .frame(width: 44, height: 44)
                    .opacity(canGoToNextDay ? 1 : 0.3)
                    .disabled(!canGoToNextDay)
                    .buttonStyle(.plain)
                }
                .foregroundColor(AppColors.ink)
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
                                
                                if !appState.safeModeHideCalories {
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
                            await appState.copyLogs(from: yesterdayDate(), to: selectedDate)
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
                            showCalories: !appState.safeModeHideCalories,
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
                    Text(LogSummaryService.title(for: group.mealType))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
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
                            .foregroundColor(.white)
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
        
        baseList.searchable(text: $searchText, prompt: hasLogs ? "Søk i dagens logg" : "Søk i logg")
    }
    
    private var groupedLogs: [(mealType: String, logs: [FoodLog])] {
        let logs = selectedSummary?.logs ?? []
        return LogSummaryService.groupedLogs(
            logs: logs,
            searchText: searchText,
            mealFilter: mealFilter,
            productNameLookup: { appState.getProduct($0)?.name ?? "" }
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
    
    private var dayTitle: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "I dag"
        }
        if Calendar.current.isDateInYesterday(selectedDate) {
            return "I går"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "d. MMM"
        return formatter.string(from: selectedDate)
    }
    
    private var canGoToNextDay: Bool {
        !Calendar.current.isDateInToday(selectedDate)
    }
    
    private func shiftSelectedDate(by days: Int) {
        if days > 0, Calendar.current.isDateInToday(selectedDate) {
            return
        }
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func yesterdayDate() -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
    }
    
    private func loadSelectedSummary() async {
        selectedSummary = await appState.fetchSummary(for: selectedDate)
        if Calendar.current.isDateInToday(selectedDate) {
            yesterdaySummary = await appState.fetchSummary(for: yesterdayDate())
        } else {
            yesterdaySummary = nil
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
            }
            .navigationTitle("Filter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Nullstill") {
                        selected = nil
                    }
                    .foregroundColor(AppColors.brand)
                }
            }
        }
    }
}

struct EditLogView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let log: FoodLog
    let onSave: (Float, String) -> Void
    
    @State private var amountText: String = ""
    @State private var selectedMealType: String = "lunsj"
    
    private let mealTypes = ["Frokost", "Lunsj", "Middag", "Snacks"]
    private let mealTypeKeys = ["frokost", "lunsj", "middag", "snacks"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mengde") {
                    TextField("Gram", text: $amountText)
                        .keyboardType(.numberPad)
                }
                
                Section("Måltid") {
                    Picker("Måltid", selection: $selectedMealType) {
                        ForEach(0..<mealTypes.count, id: \.self) { index in
                            Text(mealTypes[index]).tag(mealTypeKeys[index])
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Rediger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lagre") {
                        let grams = Float(amountText.filter { $0.isNumber }) ?? 0
                        onSave(max(0, grams), selectedMealType)
                        dismiss()
                    }
                    .disabled(amountText.isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.brand)
                }
            }
            .onAppear {
                amountText = String(Int(log.amountG))
                selectedMealType = log.mealType
            }
        }
    }
}
