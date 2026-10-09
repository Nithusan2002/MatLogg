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
    var isTab = false
    var focusOnAppear = false
    var isFirstLog = false
    let onScan: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    var onSavedMealLogComplete: () -> Void = {}
    var productSelectionContent: ((Product) -> AnyView)? = nil

    var body: some View {
        if let repository {
            FoodSearchContent(repository: repository, isTab: isTab, focusOnAppear: focusOnAppear, isFirstLog: isFirstLog,
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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var draftViewModel: FoodLoggingDraftViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSavedMeals = false
    @State private var showManualProduct = false
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let productSelectionContent: ((Product) -> AnyView)?
    private let isTab: Bool
    private let focusOnAppear: Bool
    private let isFirstLog: Bool
    private let onScan: () -> Void
    private let onSavedMealLogComplete: () -> Void
    private let onLogComplete: (ReceiptPayload) -> Void

    init(repository: any FoodSearchRepository, isTab: Bool, focusOnAppear: Bool, isFirstLog: Bool,
         onScan: @escaping () -> Void,
         onLogComplete: @escaping (ReceiptPayload) -> Void,
         onSavedMealLogComplete: @escaping () -> Void,
         productSelectionContent: ((Product) -> AnyView)?) {
        _viewModel = StateObject(wrappedValue: FoodSearchViewModel(repository: repository))
        self.productSelectionContent = productSelectionContent
        self.isTab = isTab
        self.focusOnAppear = focusOnAppear
        self.isFirstLog = isFirstLog
        self.onScan = onScan
        self.onLogComplete = onLogComplete
        self.onSavedMealLogComplete = onSavedMealLogComplete
    }

    var body: some View {
        VStack(spacing: isTab && !dynamicTypeSize.isAccessibilitySize ? 0 : 16) {
            if !isFirstLog && !dynamicTypeSize.isAccessibilitySize {
                searchControls.padding(.horizontal, 16)
            }
            if isTab {
                searchList
                    .contentMargins(.top, 0, for: .scrollContent)
                    .matLoggTabBarScrollClearance()
            } else {
                searchList
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
                    Button("Ferdig") { searchFocused = false }
                        .foregroundColor(AppColors.actionText)
                }
            }
        }
    }

    private var searchControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityHidden(true)
                TextField("Søk etter mat eller produkt", text: Binding(
                    get: { viewModel.query }, set: { viewModel.setQuery($0) }
                ))
                .font(AppTypography.body)
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

            if isFirstLog {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 8) { searchButton; scanButton; manualRegistrationButton }
                } else {
                    HStack(spacing: 8) { searchButton; scanButton; manualRegistrationButton }
                }
            } else if productSelectionContent != nil {
                searchButton
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) { searchButton; scanButton }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { searchButton; scanButton }
                    VStack(spacing: 8) { searchButton; scanButton }
                }
            }
            if !isFirstLog && productSelectionContent == nil { manualRegistrationButton }
            searchStatus
        }
    }

    private var searchStatus: some View {
        let message = viewModel.showsSearchFeedback ? "Henter flere produkter …"
            : viewModel.showsCatalogFeedback ? "Henter flere matvarer …"
            : viewModel.hasQuery && viewModel.phase == .local && !isFirstLog
                ? "Trykk Søk for flere produkter." : ""
        return HStack(spacing: 8) {
            ActivityIndicatorSlot(isActive: viewModel.showsSearchFeedback || viewModel.showsCatalogFeedback,
                                  label: "Henter matvarer")
            ZStack(alignment: .leading) {
                Text("Trykk Søk for flere produkter.").hidden()
                Text("Henter flere produkter …").hidden()
                Text("Henter flere matvarer …").hidden()
                Text(message)
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
            .accessibilityHidden(message.isEmpty)
        }
    }

    private var manualRegistrationButton: some View {
        Button { searchFocused = false; showManualProduct = true } label: {
            actionLabel(isFirstLog ? "Manuelt" : "Registrer manuelt", symbol: "square.and.pencil")
                .font(AppTypography.bodyEmphasis)
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
                .fixedSize(horizontal: false, vertical: true)
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
                .font(AppTypography.bodyEmphasis)
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

    private var searchList: some View {
        List {
            if productSelectionContent == nil,
               draftViewModel.draft != nil || draftViewModel.errorMessage != nil {
                Section { LoggingDraftBanner(onLogComplete: onLogComplete) }
                    .listRowBackground(AppColors.background)
                    .listRowSeparator(.hidden)
            }
            if !isFirstLog && dynamicTypeSize.isAccessibilitySize {
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
        if viewModel.favorites.isEmpty && viewModel.recent.isEmpty {
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

    private var context: String {
        let source = switch product.nutritionSource {
        case .matvaretabellen: "Matvaretabellen"
        case .openFoodFacts: "Open Food Facts"
        case .user: "Brukeroppgitt"
        }
        return "\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal per 100 \(product.amountUnit.rawValue) · \(source)"
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
                             placeholderSystemImage: product.kind == .genericFood ? "fork.knife" : "shippingbox")
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
                Text(product.name).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                Text(context).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
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
