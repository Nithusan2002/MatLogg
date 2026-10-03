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

    var body: some View {
        if let repository {
            FoodSearchContent(repository: repository, isTab: isTab, focusOnAppear: focusOnAppear, isFirstLog: isFirstLog,
                              onScan: onScan, onLogComplete: onLogComplete)
        } else {
            ContentUnavailableView("Søk er utilgjengelig", systemImage: "magnifyingglass")
        }
    }
}

private struct FoodSearchContent: View {
    @StateObject private var viewModel: FoodSearchViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showManualProduct = false
    @FocusState private var searchFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let isTab: Bool
    private let focusOnAppear: Bool
    private let isFirstLog: Bool
    private let onScan: () -> Void
    private let onLogComplete: (ReceiptPayload) -> Void

    init(repository: any FoodSearchRepository, isTab: Bool, focusOnAppear: Bool, isFirstLog: Bool,
         onScan: @escaping () -> Void,
         onLogComplete: @escaping (ReceiptPayload) -> Void) {
        _viewModel = StateObject(wrappedValue: FoodSearchViewModel(repository: repository))
        self.isTab = isTab
        self.focusOnAppear = focusOnAppear
        self.isFirstLog = isFirstLog
        self.onScan = onScan
        self.onLogComplete = onLogComplete
    }

    var body: some View {
        VStack(spacing: 16) {
            if !isFirstLog && !dynamicTypeSize.isAccessibilitySize {
                searchControls.padding(.horizontal, 16)
            }
            if isTab {
                searchList.matLoggTabBarScrollClearance()
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await reload() } }
        }
        .preference(key: MatLoggTabBarEditingKey.self, value: isTab && searchFocused)
        .onDisappear {
            searchFocused = false
            viewModel.suspend()
        }
        .sheet(item: $viewModel.selectedProduct, onDismiss: { Task { await reload() } }) { product in
            ProductDetailView(product: product, appState: appState, onLogComplete: onLogComplete)
        }
        .fullScreenCover(isPresented: $showManualProduct, onDismiss: {
            viewModel.finishManualCreation()
            Task { await reload() }
        }) {
            ManualProductView(barcode: nil, saveProduct: viewModel.saveManual, onSaved: viewModel.manualProductSaved)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { searchFocused = false }
                    .foregroundColor(AppColors.action)
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
            } else if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) { searchButton; scanButton }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { searchButton; scanButton }
                    VStack(spacing: 8) { searchButton; scanButton }
                }
            }
            if !isFirstLog { manualRegistrationButton }
        }
    }

    private var manualRegistrationButton: some View {
        Button { searchFocused = false; showManualProduct = true } label: {
            actionLabel(isFirstLog ? "Manuelt" : "Registrer manuelt", symbol: "square.and.pencil")
                .font(AppTypography.bodyEmphasis)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundColor(AppColors.action)
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
                .foregroundColor(AppColors.action)
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
            if !isFirstLog && dynamicTypeSize.isAccessibilitySize {
                Section { searchControls }
                    .listRowBackground(AppColors.background)
                    .listRowSeparator(.hidden)
            }
            if isFirstLog {
                Section {
                    let informationLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
                    informationLayout {
                        Text("Lagres på denne iPhonen. Konto og mål er valgfrie.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        if let url = PrivacyConstants.privacyPolicyURL {
                            Link("Personvern", destination: url)
                                .font(AppTypography.captionEmphasis)
                                .frame(minHeight: 44)
                        }
                    }
                    searchControls
                    if !viewModel.hasQuery {
                        Text("Matloggene lagres på denne enheten uten skybackup. Data kan gå tapt hvis du sletter appen eller mister telefonen. Du kan eksportere en kopi under Profil.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .accessibilityIdentifier("local-storage-explanation")
                    }
                }
                .listRowBackground(AppColors.background)
                .listRowSeparator(.hidden)
            }
            if viewModel.isLoading {
                Section { ProgressView("Henter matvarer …").frame(maxWidth: .infinity, minHeight: 80) }
            } else {
                if viewModel.isLoadingCatalog {
                    Section { ProgressView("Henter flere matvarer …") }
                }
                if let error = viewModel.loadError {
                    Section {
                        Text(error).foregroundColor(AppColors.textSecondary)
                        Button("Prøv igjen") { Task { await reload() } }
                    }
                }
                if let error = viewModel.selectionError {
                    Section { Text(error).foregroundColor(AppColors.textSecondary) }
                }
                if viewModel.isPreparing {
                    Section { ProgressView("Åpner matvare …") }
                }
                if viewModel.hasQuery {
                    results
                } else if isFirstLog {
                    Section("Velg en matvare") { productRows(viewModel.suggestions) }
                        .listRowBackground(AppColors.surface)
                } else {
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

    @ViewBuilder
    private var library: some View {
        Section("Favoritter") {
            if viewModel.favorites.isEmpty {
                Text("Trykk på hjertet på en matvare for å finne den raskt igjen her.")
                    .font(AppTypography.body).foregroundColor(AppColors.textSecondary)
            } else {
                productRows(viewModel.favorites, context: "favorite")
            }
        }
        .listRowBackground(AppColors.surface)
        Section("Nylig brukt") {
            if viewModel.recent.isEmpty {
                Text("Matvarer du loggfører vises her neste gang.")
                    .font(AppTypography.body).foregroundColor(AppColors.textSecondary)
            } else {
                productRows(viewModel.recent, context: "recent")
            }
        }
        .listRowBackground(AppColors.surface)
        if !viewModel.suggestions.isEmpty {
            Section("Råvarer") { productRows(viewModel.suggestions) }
                .listRowBackground(AppColors.surface)
        }
    }

    @ViewBuilder
    private var results: some View {
        Section {
            if viewModel.phase == .searching {
                ProgressView("Henter flere produkter …")
            } else if let error = viewModel.searchError {
                Text(error).font(AppTypography.body).foregroundColor(AppColors.textSecondary)
                Button("Prøv igjen", action: submitSearch).frame(minHeight: 44)
            } else if viewModel.phase == .local && !isFirstLog {
                Text("Lokale treff vises mens du skriver. Trykk Søk for flere produkter.")
                    .font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
        }
        .listRowBackground(AppColors.surface)
        if !viewModel.results.isEmpty {
            Section(viewModel.phase == .complete ? "Resultater" : "Lagrede matvarer og råvarer") {
                productRows(viewModel.results)
            }
            .listRowBackground(AppColors.surface)
        } else if viewModel.phase != .searching && viewModel.phase != .failure {
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
    }

    private func productRows(_ products: [Product], context: String = "result") -> some View {
        ForEach(products) { product in
            Button {
                searchFocused = false
                Task { await viewModel.open(product) }
            } label: {
                FoodSearchProductRow(product: product)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isPreparing)
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

    private var context: String {
        let source = switch product.nutritionSource {
        case .matvaretabellen: "Matvaretabellen"
        case .openFoodFacts: "Open Food Facts"
        case .user: "Brukeroppgitt"
        }
        return "\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal per 100 \(product.amountUnit.rawValue) · \(source)"
    }

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnailView(url: product.imageUrl.flatMap(URL.init(string:)), localData: product.localImageData,
                                 placeholderSystemImage: product.kind == .genericFood ? "fork.knife" : "shippingbox")
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name).font(AppTypography.bodyEmphasis).foregroundColor(AppColors.ink)
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
                }
                Text(context).font(AppTypography.caption).foregroundColor(AppColors.textSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}
