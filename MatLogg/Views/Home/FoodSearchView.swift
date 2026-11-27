import SwiftUI

private struct FoodSearchRepositoryKey: EnvironmentKey {
    static let defaultValue: (any FoodSearchRepository)? = nil
}

extension EnvironmentValues {
    var foodSearchRepository: (any FoodSearchRepository)? {
        get { self[FoodSearchRepositoryKey.self] }
        set { self[FoodSearchRepositoryKey.self] = newValue }
    }
}

/// The app root supplies IO; each presentation owns its own search state.
struct FoodSearchView: View {
    @Environment(\.foodSearchRepository) private var repository
    var refreshRevision = 0
    var isUnifiedLogging = false
    var isTab = false
    var focusOnAppear = false
    var isFirstLog = false
    let onScan: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    var onSavedMealLogComplete: () -> Void = {}
    var productSelectionContent: ((Product) -> AnyView)? = nil

    var body: some View {
        if let repository {
            FoodSearchContent(repository: repository, refreshRevision: refreshRevision, isUnifiedLogging: isUnifiedLogging, isTab: isTab, focusOnAppear: focusOnAppear, isFirstLog: isFirstLog,
                              onScan: onScan, onLogComplete: onLogComplete,
                              onSavedMealLogComplete: onSavedMealLogComplete,
                              productSelectionContent: productSelectionContent)
        } else {
            ContentUnavailableView("Søk er utilgjengelig", systemImage: "magnifyingglass")
        }
    }
}

private struct FoodSearchContent: View {
    @StateObject private var viewModel: FoodSearchViewModel
    @EnvironmentObject private var productViewModel: ProductViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var quickLog: QuickLogViewModel
    @EnvironmentObject private var logs: LogViewModel
    @EnvironmentObject private var draftViewModel: FoodLoggingDraftViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSavedMeals = false
    @State private var showManualProduct = false
    @State private var showsLoggingCalendar = false
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let productSelectionContent: ((Product) -> AnyView)?
    private let refreshRevision: Int
    @EnvironmentObject private var savedMeals: SavedMealsViewModel
    @State private var selectedSavedMeal: SavedMeal?
    private let isUnifiedLogging: Bool
    private let isTab: Bool
    private let focusOnAppear: Bool
    private let isFirstLog: Bool
    private let onScan: () -> Void
    private let onSavedMealLogComplete: () -> Void
    private let onLogComplete: (ReceiptPayload) -> Void

    init(repository: any FoodSearchRepository, refreshRevision: Int, isUnifiedLogging: Bool, isTab: Bool, focusOnAppear: Bool, isFirstLog: Bool,
         onScan: @escaping () -> Void,
         onLogComplete: @escaping (ReceiptPayload) -> Void,
         onSavedMealLogComplete: @escaping () -> Void,
         productSelectionContent: ((Product) -> AnyView)?) {
        _viewModel = StateObject(wrappedValue: FoodSearchViewModel(repository: repository))
        self.productSelectionContent = productSelectionContent
        self.refreshRevision = refreshRevision
        self.isUnifiedLogging = isUnifiedLogging
        self.isTab = isTab
        self.focusOnAppear = focusOnAppear
        self.isFirstLog = isFirstLog
        self.onScan = onScan
        self.onLogComplete = onLogComplete
        self.onSavedMealLogComplete = onSavedMealLogComplete
    }

    var body: some View {
        VStack(spacing: 16) {
            if !isUnifiedLogging && !isFirstLog && !dynamicTypeSize.isAccessibilitySize {
                searchControls.padding(.horizontal, 16)
            }
            if isTab {
                searchList
                    .contentMargins(.top, 0, for: .scrollContent)
                    .matLoggTabBarScrollClearance()
            } else {
                searchList
                    .contentMargins(.top, 0, for: .scrollContent)
            }
        }
        .padding(.top, 8)
        .background(AppColors.background.ignoresSafeArea())
        .task(id: authViewModel.currentUser?.id) {
            await viewModel.load(owner: authViewModel.currentUser?.id)
            guard !Task.isCancelled else { return }
            if focusOnAppear { searchFocused = true }
        }
        .task(id: authViewModel.currentUser?.id) {
            await draftViewModel.load(owner: authViewModel.currentUser?.id)
        }
        .task(id: refreshRevision) {
            if refreshRevision > 0 {
                await reload()
                await quickLog.load(userId: authViewModel.currentUser?.id)
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            if isUnifiedLogging {
                async let meals: Void = savedMeals.load(userId: authViewModel.currentUser?.id)
                async let recent: Void = quickLog.load(userId: authViewModel.currentUser?.id)
                _ = await (meals, recent)
            }
        }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            showSavedMeals = false
            selectedSavedMeal = nil
            showManualProduct = false
            showsLoggingCalendar = false
        }
        .onChange(of: productViewModel.metadataRevision) { _, _ in
            Task { await reload() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .preference(key: MatLoggTabBarEditingKey.self, value: isTab && searchFocused)
        .onDisappear {
            searchFocused = false
            viewModel.suspend()
        }
        .sheet(item: $viewModel.selectedProduct, onDismiss: { Task { await reload() } }) { product in
            if let productSelectionContent {
                productSelectionContent(product)
            } else {
                ProductDetailView(product: product, appState: appState, onLogComplete: onLogComplete)
            }
        }
        .sheet(item: $quickLog.selectedQuickProduct, onDismiss: { Task { await reload() } }) { product in
            ProductDetailView(product: product, appState: appState, onLogComplete: onLogComplete)
        }
        .sheet(item: $selectedSavedMeal, onDismiss: { Task { await reload() } }) { meal in
            SavedMealLogView(meal: meal) {
                selectedSavedMeal = nil
                onSavedMealLogComplete()
            }
        }
        .sheet(isPresented: $showSavedMeals, onDismiss: { Task { await reload() } }) {
            SavedMealsListView {
                showSavedMeals = false
                onSavedMealLogComplete()
            }
        }
        .fullScreenCover(isPresented: $showManualProduct, onDismiss: {
            viewModel.finishManualCreation()
            Task { await reload() }
        }) {
            if productSelectionContent == nil {
                RecoverableManualLoggingView(onLogComplete: onLogComplete)
            } else {
                ManualProductView(barcode: nil, saveProduct: viewModel.saveManual, onSaved: viewModel.manualProductSaved)
            }
        }
        .toolbar {
            if searchFocused {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isUnifiedLogging ? "Skjul tastatur" : "Ferdig") { searchFocused = false }
                        .accessibilityIdentifier("food-search-hide-keyboard")
                        .foregroundColor(AppColors.actionText)
                }
            }
        }
    }

    private var searchControls: some View {
        VStack(spacing: 8) {
            if isUnifiedLogging {
                unifiedSearchControls
            } else {
                if isFirstLog || dynamicTypeSize.isAccessibilitySize {
                    searchInput
                } else {
                    HStack(spacing: 8) {
                        searchInput
                        searchButton.frame(width: 104)
                    }
                }

                if isFirstLog {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(spacing: 8) { searchButton; scanButton; manualRegistrationButton }
                    } else {
                        HStack(spacing: 8) { searchButton; scanButton; manualRegistrationButton }
                    }
                } else {
                    if dynamicTypeSize.isAccessibilitySize { searchButton }
                    if productSelectionContent == nil {
                        if dynamicTypeSize.isAccessibilitySize {
                            VStack(spacing: 8) { scanButton; manualRegistrationButton }
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) { scanButton; manualRegistrationButton }
                                VStack(spacing: 8) { scanButton; manualRegistrationButton }
                            }
                        }
                    }
                }
            }
            searchStatus
        }
        .buttonStyle(.plain)
    }

    private var unifiedSearchControls: some View {
        VStack(spacing: 8) {
            if dynamicTypeSize >= .xxxLarge {
                searchInput
                unifiedScanButton
            } else {
                HStack(spacing: 8) {
                    searchInput
                    unifiedScanButton.fixedSize(horizontal: true, vertical: false)
                }
            }
            manualRegistrationButton
            if viewModel.hasQuery {
                Button(action: submitSearch) {
                    Text("Søk etter produkter")
                        .font(AppTypography.secondaryEmphasis)
                        .foregroundStyle(AppColors.actionText)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .disabled(viewModel.isLoading || viewModel.phase == .searching)
                .accessibilityHint("Henter også produkter fra Open Food Facts")
                .accessibilityIdentifier("food-search-submit")
            }
        }
    }

    private var unifiedScanButton: some View {
        Button { searchFocused = false; onScan() } label: {
            HStack(spacing: 8) {
                Image(systemName: "barcode.viewfinder")
                    .accessibilityHidden(true)
                Text("Skann")
                    .fixedSize(horizontal: true, vertical: true)
            }
                .font(AppTypography.bodyEmphasis)
                .padding(.horizontal, 16)
                .frame(maxWidth: dynamicTypeSize >= .xxxLarge ? .infinity : nil)
                .frame(height: dynamicTypeSize >= .xxxLarge ? nil : 52)
                .frame(minHeight: 52)
                .foregroundStyle(AppColors.surface)
                .background(AppColors.deepInk, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Skann strekkode")
        .accessibilityIdentifier("logging-scan")
    }

    private var searchInput: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)
            TextField(isUnifiedLogging ? "Søk etter mat" : "Søk etter mat eller produkt", text: Binding(
                get: { viewModel.query }, set: { viewModel.setQuery($0) }
            ))
            .font(AppTypography.body)
            .frame(minHeight: isUnifiedLogging ? 44 : nil)
            .contentShape(Rectangle())
            .focused($searchFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .onSubmit { submitSearch() }
            .accessibilityIdentifier("food-search-field")
            if viewModel.hasQuery {
                Button { viewModel.setQuery(""); searchFocused = true } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Tøm søket")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, viewModel.hasQuery ? 0 : 14)
        .frame(minHeight: 52)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.controlBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var searchStatus: some View {
        let message = viewModel.showsSearchFeedback ? "Henter flere produkter …"
            : viewModel.showsCatalogFeedback ? "Henter flere matvarer …"
            : viewModel.hasQuery && viewModel.phase == .local && !isFirstLog && !isUnifiedLogging
                ? "Trykk Søk for flere produkter." : ""
        if !message.isEmpty {
            HStack(spacing: 8) {
                ActivityIndicatorSlot(isActive: viewModel.showsSearchFeedback || viewModel.showsCatalogFeedback,
                                      label: "Henter matvarer")
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
        }
    }

    private var manualRegistrationButton: some View {
        Button { searchFocused = false; showManualProduct = true } label: {
            actionLabel(isFirstLog ? "Manuelt" : "Registrer manuelt", symbol: "square.and.pencil")
                .font(isFirstLog ? AppTypography.bodyEmphasis : AppTypography.secondaryEmphasis)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(AppColors.actionText)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        }
        .accessibilityIdentifier("food-search-manual-registration")
    }

    private var searchButton: some View {
        Button(action: submitSearch) {
            actionLabel("Søk", symbol: "magnifyingglass")
                .font(AppTypography.bodyEmphasis)
                .fixedSize(horizontal: true, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(AppColors.surface)
                .background(AppColors.action, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!viewModel.hasQuery || viewModel.isLoading || viewModel.phase == .searching)
        .opacity(!viewModel.hasQuery || viewModel.isLoading ? 0.5 : 1)
        .accessibilityHint("Henter også produkter fra Open Food Facts")
        .accessibilityIdentifier("food-search-submit")
    }

    private var scanButton: some View {
        Button { searchFocused = false; onScan() } label: {
            actionLabel(isFirstLog ? "Skann" : "Skann strekkode", symbol: "barcode.viewfinder")
                .font(isFirstLog ? AppTypography.bodyEmphasis : AppTypography.secondaryEmphasis)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(AppColors.actionText)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func actionLabel(_ title: String, symbol: String) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(title)
        } else {
            Label(title, systemImage: symbol)
        }
    }

    @ViewBuilder private var searchList: some View {
        if isUnifiedLogging {
            searchListContent.listSectionSpacing(12)
        } else {
            searchListContent
        }
    }

    private var searchListContent: some View {
        List {
            if isUnifiedLogging {
                Section {
                    VStack(spacing: 12) {
                        // Keep the List row's runtime metadata independent of the
                        // nested calendar, menu and alternate search layouts.
                        AnyView(loggingContext)
                        AnyView(searchControls)
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(AppColors.background)
                .listRowSeparator(.hidden)
            }
            if productSelectionContent == nil,
               draftViewModel.draft != nil || draftViewModel.errorMessage != nil {
                Section { LoggingDraftBanner(presentation: .row, onLogComplete: onLogComplete) }
                    .listRowBackground(AppColors.surface)
                    .listRowSeparator(.hidden)
            }
            if !isUnifiedLogging && !isFirstLog && dynamicTypeSize.isAccessibilitySize {
                Section { searchControls }
                    .listRowBackground(AppColors.background)
                    .listRowSeparator(.hidden)
            }
            if isFirstLog {
                Section {
                    VStack(alignment: .leading, spacing: 20) {
                        if !viewModel.hasQuery {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Logg din første matvare")
                                    .font(AppTypography.title)
                                    .foregroundStyle(AppColors.deepInk)
                                    .accessibilityAddTraits(.isHeader)
                                Text("Finn noe du har spist. Velg mengde og lagre.")
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        searchControls
                        if !viewModel.hasQuery {
                            firstLogStorageInformation
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(AppColors.background)
                .listRowSeparator(.hidden)
            }
            if isTab && !viewModel.hasQuery {
                Section {
                    Button {
                        searchFocused = false
                        showSavedMeals = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.stack.3d.up")
                                .foregroundStyle(AppColors.actionText)
                                .accessibilityHidden(true)
                            Text("Lagrede måltider")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppColors.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Åpner alle lagrede måltider for logging, redigering og sletting")
                    .accessibilityIdentifier("food-search-saved-meals")
                }
                .listRowBackground(AppColors.surface)
            }
            if viewModel.isLoading {
                Section { ProgressView("Henter matvarer …").frame(maxWidth: .infinity, minHeight: 80) }
            } else {
                if let error = viewModel.loadError {
                    Section {
                        ErrorMessageView(error)
                        Button("Prøv igjen") { Task { await reload() } }
                    }
                }
                if let error = viewModel.selectionError {
                    Section { ErrorMessageView(error) }
                }
                if viewModel.hasQuery {
                    results
                } else if !isFirstLog || !viewModel.favorites.isEmpty || !viewModel.recent.isEmpty {
                    library
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .tint(AppColors.action)
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await reload() }
    }

    private var loggingContext: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Måltid")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.deepInk)
                Spacer(minLength: 8)
                Button { searchFocused = false; showsLoggingCalendar = true } label: {
                    Label(loggingDateTitle, systemImage: "calendar")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .font(AppTypography.secondary)
                .foregroundStyle(AppColors.textSecondary)
                .accessibilityLabel("Loggdato, \(appState.logSelectedDate.formatted(date: .complete, time: .omitted))")
                .accessibilityHint("Åpner kalenderen")
                .accessibilityIdentifier("logging-date")
                .sheet(isPresented: $showsLoggingCalendar) {
                    NavigationStack {
                        ScrollView {
                            DatePicker("Loggdato", selection: $appState.logSelectedDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .accessibilityIdentifier("logging-calendar")
                                .environment(\.locale, Locale(identifier: "nb_NO"))
                                .padding(.horizontal, 16)
                        }
                        .background(AppColors.background.ignoresSafeArea())
                        .navigationTitle("Velg dato")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Ferdig") { showsLoggingCalendar = false }
                                    .accessibilityIdentifier("logging-calendar-done")
                            }
                        }
                    }
                    .tint(AppColors.actionText)
                    .presentationBackground(AppColors.background)
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(460), .large])
                    .presentationDragIndicator(.visible)
                }
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                ForEach(MealPresentation.all) { meal in
                    Button { appState.selectedMealType = meal.key } label: {
                        Text(appState.selectedMealType == meal.key ? "\(meal.title) ✓" : meal.title)
                            .font(AppTypography.captionEmphasis)
                            .foregroundStyle(appState.selectedMealType == meal.key ? AppColors.onVibrant : AppColors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(appState.selectedMealType == meal.key ? AppColors.brand : AppColors.surface, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Logg til \(meal.title)")
                    .accessibilityAddTraits(appState.selectedMealType == meal.key ? .isSelected : [])
                    .accessibilityIdentifier("logging-meal-\(meal.key)")
                }
            }
        }
    }

    private var loggingDateTitle: String {
        if Calendar.current.isDateInToday(appState.logSelectedDate) { return "I dag" }
        return appState.logSelectedDate.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO")))
    }

    private var firstLogStorageInformation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("På denne iPhonen", systemImage: "iphone")
                .font(AppTypography.captionEmphasis)
                .foregroundStyle(AppColors.ink)
            Text("Konto og mål er valgfrie. Matloggene lagres uten skybackup og kan gå tapt hvis du sletter appen eller mister telefonen. Du kan eksportere en kopi under Profil.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("local-storage-explanation")
            if let url = PrivacyConstants.privacyPolicyURL {
                Link("Personvern", destination: url)
                    .font(AppTypography.captionEmphasis)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.warmSurface, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var library: some View {
        if isUnifiedLogging {
            Section {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(spacing: 2))
                    : AnyLayout(HStackLayout(spacing: 2))
                layout {
                    ForEach(FoodSearchViewModel.ReuseList.allCases, id: \.self) { list in
                        Button { viewModel.reuseList = list } label: {
                            Text(list.rawValue)
                                .font(AppTypography.secondaryEmphasis)
                                .foregroundStyle(viewModel.reuseList == list ? AppColors.deepInk : AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 8)
                                .background(viewModel.reuseList == list ? AppColors.surface : Color.clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(viewModel.reuseList == list ? .isSelected : [])
                        .accessibilityIdentifier("logging-reuse-\(list == .recent ? "recent" : list == .favorites ? "favorites" : "saved")")
                    }
                }
                .padding(4)
                .background(AppColors.mutedSurface, in: RoundedRectangle(cornerRadius: 16))
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(AppColors.background)
            if viewModel.reuseList == .recent {
                Section {
                    if viewModel.recent.isEmpty { Text("Matvarer du logger, vises her.") }
                    if let error = quickLog.logError { ErrorMessageView(error) }
                    ForEach(quickLog.recentFoods) { food in
                        recentFoodRow(food)
                    }
                    if quickLog.recentFoods.isEmpty { productRows(viewModel.recent, context: "recent") }
                }.listRowBackground(AppColors.surface)
            } else if viewModel.reuseList == .saved {
                Section {
                    if savedMeals.isLoading && savedMeals.meals.isEmpty { ProgressView("Henter lagrede måltider …") }
                    if let error = savedMeals.loadError {
                        ErrorMessageView(error)
                        Button("Prøv igjen") { Task { await savedMeals.load(userId: authViewModel.currentUser?.id) } }
                    } else if !savedMeals.isLoading && savedMeals.meals.isEmpty {
                        Text("Lagre et registrert måltid fra •••-menyen ved Måltider på Hjem.")
                    }
                    ForEach(savedMeals.meals.prefix(3)) { meal in
                        Button { selectedSavedMeal = meal } label: { SavedMealRow(meal: meal) }
                            .buttonStyle(.plain)
                    }
                    Button("Se alle lagrede måltider") { showSavedMeals = true }
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("food-search-saved-meals")
                }.listRowBackground(AppColors.surface)
            } else {
                Section {
                    if viewModel.favorites.isEmpty { Text("Trykk på hjertet på en matvare for å lagre den som favoritt.") }
                    productRows(viewModel.favorites, context: "favorite")
                }.listRowBackground(AppColors.surface)
            }
        } else if viewModel.favorites.isEmpty && viewModel.recent.isEmpty {
            Section {
                Text("Søk etter en matvare for å komme i gang.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityIdentifier("food-search-empty-library")
            }
            .listRowBackground(AppColors.surface)
        } else {
            if !viewModel.favorites.isEmpty {
                Section("Favoritter") {
                    productRows(viewModel.favorites, context: "favorite")
                }
                .listRowBackground(AppColors.surface)
            }
            if !viewModel.recent.isEmpty {
                Section("Nylig brukt") {
                    productRows(viewModel.recent, context: "recent")
                }
                .listRowBackground(AppColors.surface)
            }
        }
    }

    private func recentFoodRow(_ food: RecentFood) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button {
                searchFocused = false
                Task { await viewModel.open(food.product) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.product.name).font(AppTypography.bodyEmphasis)
                    Text("Sist logget: \(food.amountLabel)").font(AppTypography.caption)
                }
                .foregroundStyle(AppColors.deepInk)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.trailing, 20)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.right")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.trailing, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Åpner mengdevalg og loggføring")
            .accessibilityIdentifier("food-search-recent-\(food.id.uuidString)")
            Button(food.canRepeat ? "Loggfør" : "Kontroller mengde") {
                searchFocused = false
                if food.canRepeat {
                    let owner = authViewModel.currentUser?.id
                    let date = appState.logSelectedDate
                    let meal = appState.selectedMealType
                    Task {
                        guard await quickLog.logAgain(food, mealType: meal, date: date) != nil,
                              authViewModel.currentUser?.id == owner,
                              let receipt = quickLog.repeatReceipt else { return }
                        quickLog.dismissRepeatReceipt()
                        logs.didPersistExternalLog()
                        onLogComplete(receipt)
                    }
                } else {
                    Task { await viewModel.open(food.product) }
                }
            }
            .buttonStyle(.plain)
            .font(AppTypography.secondaryEmphasis)
            .foregroundStyle(AppColors.actionText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(AppColors.chipFillSelected, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel("Loggfør \(food.product.name), \(food.amountLabel)")
            .accessibilityHint("Til \(LogSummaryService.title(for: appState.selectedMealType)) på valgt dato")
            .accessibilityIdentifier("quick-log-repeat-\(food.id.uuidString)")
        }
        .disabled(quickLog.isRepeating || quickLog.isUndoingRepeat)
    }

    @ViewBuilder
    private var results: some View {
        if let error = viewModel.searchError {
            Section {
                ErrorMessageView(error).font(AppTypography.body)
                Button("Prøv igjen", action: submitSearch).frame(minHeight: 44)
            }
            .listRowBackground(AppColors.surface)
        }
        if !viewModel.resultSections.history.isEmpty {
            Section("Tidligere logget") {
                productRows(viewModel.resultSections.history, context: "history")
            }
            .listRowBackground(AppColors.surface)
        }
        if !viewModel.resultSections.other.isEmpty {
            Section(viewModel.resultSections.history.isEmpty
                    ? (viewModel.phase == .complete ? "Resultater" : "Lagrede matvarer og råvarer")
                    : "Andre treff") {
                productRows(viewModel.resultSections.other)
            }
            .listRowBackground(AppColors.surface)
        } else if viewModel.results.isEmpty && viewModel.phase != .searching && viewModel.phase != .failure {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(viewModel.phase == .local ? "Ingen lokale treff" : "Ingen treff")
                        .font(AppTypography.sectionTitle)
                    Text("Prøv et kortere navn, skann strekkoden eller registrer matvaren manuelt.")
                        .font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(AppColors.surface)
        }
        globalSearchSection
    }

    @ViewBuilder
    private var globalSearchSection: some View {
        if viewModel.canSearchGlobally || (viewModel.hasSearchedGlobally && viewModel.globalResults.isEmpty) {
            Section {
                if let error = viewModel.globalSearchError {
                    ErrorMessageView(error).font(AppTypography.body)
                }
                if viewModel.isSearchingGlobally {
                    ProgressView("Søker i hele verden …")
                        .frame(minHeight: 44)
                } else if viewModel.hasSearchedGlobally {
                    if viewModel.globalResults.isEmpty {
                        Text("Ingen flere treff i det globale søket.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else {
                    Text("Finner du ikke varen?")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)
                    Button(viewModel.globalSearchError == nil ? "Søk i hele verden" : "Prøv globalt søk igjen") {
                        searchFocused = false
                        viewModel.searchGlobally()
                    }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("food-search-global")
                }
            }
            .listRowBackground(AppColors.surface)
        }
        if !viewModel.globalResults.isEmpty {
            Section("Flere treff fra hele verden") {
                productRows(viewModel.globalResults)
            }
            .listRowBackground(AppColors.surface)
        }
    }

    private func productRows(_ products: [Product], context: String = "result") -> some View {
        ForEach(products) { product in
            Button {
                guard !viewModel.isPreparing, viewModel.selectedProduct == nil else { return }
                searchFocused = false
                Task { await viewModel.open(product) }
            } label: {
                FoodSearchProductRow(product: product, isPreparing: viewModel.preparingProductID == product.id)
            }
            .buttonStyle(.plain)
            .accessibilityValue(viewModel.preparingProductID == product.id ? "Åpner matvare" : "")
            .accessibilityHint("Åpner mengdevalg og loggføring")
            .accessibilityIdentifier("food-search-\(context)-\(product.id.uuidString)")
        }
    }

    private func submitSearch() {
        searchFocused = false
        viewModel.search()
    }

    private func reload() async { await viewModel.load(owner: authViewModel.currentUser?.id) }
}

private struct FoodSearchProductRow: View {
    let product: Product
    let isPreparing: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let presentation: FoodSearchRowPresentation

    init(product: Product, isPreparing: Bool) {
        self.product = product
        self.isPreparing = isPreparing
        presentation = FoodSearchRowPresentation(product: product)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { thumbnail; Spacer(); trailingIndicator }
                    labels.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: 12) {
                    thumbnail
                    labels
                    Spacer(minLength: 4)
                    trailingIndicator
                }
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var thumbnail: some View {
        ProductThumbnailView(url: product.imageUrl.flatMap(URL.init(string:)), localData: product.localImageData,
                             foodGroup: product.foodGroup)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
                Text(product.name).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        if let brand = presentation.brandText { Text(brand) }
                        if let package = presentation.packageText { Text(package) }
                        Text(presentation.kindTitle)
                        Text(presentation.sourceTitle)
                    } else {
                        if let identity = presentation.identity { Text(identity) }
                        Text(presentation.provenance)
                    }
                    Text(presentation.nutrition)
                }
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            }
            .multilineTextAlignment(.leading)
    }

    private var trailingIndicator: some View {
        ZStack {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .opacity(isPreparing ? 0 : 1)
                if isPreparing {
                    ProgressView().controlSize(.small).tint(AppColors.action)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }
}
