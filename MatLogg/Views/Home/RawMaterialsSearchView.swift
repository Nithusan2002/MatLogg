import SwiftUI

struct RawMaterialsSearchView: View {
    private enum SearchState {
        case idle
        case loading
        case results
        case cachedResults
        case empty
        case failure(String)
    }

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    @Environment(\.dismiss) var dismiss
    @FocusState private var searchFocused: Bool
    
    @State private var query = ""
    @State private var curated: [MatvaretabellenProduct] = []
    @State private var searchResults: [Product] = []
    @State private var recentProducts: [Product] = []
    @State private var favoriteProducts: [Product] = []
    @State private var searchState: SearchState = .idle
    @State private var selectedProduct: Product?
    @State private var showScanCamera = false
    let onLogComplete: (ReceiptPayload) -> Void

    init(onLogComplete: @escaping (ReceiptPayload) -> Void) {
        self.onLogComplete = onLogComplete
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                CardContainer {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Søk etter mat eller produkt", text: $query)
                            .font(AppTypography.body)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onChange(of: query) { _, newValue in
                                if newValue.count > 80 {
                                    query = String(newValue.prefix(80))
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                
                List {
                    if query.isEmpty {
                        if !recentProducts.isEmpty {
                            Section("Sist brukt") {
                                ForEach(recentProducts) { product in
                                    rawRow(product: product)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                        }
                        
                        if !favoriteProducts.isEmpty {
                            Section("Favoritter") {
                                ForEach(favoriteProducts) { product in
                                    rawRow(product: product)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                        }
                        
                        Section("Vanlige råvarer") {
                            ForEach(curated, id: \.id) { item in
                                rawRow(item: item)
                            }
                        }
                        .listRowBackground(AppColors.surface)
                    } else {
                        switch searchState {
                        case .loading:
                            Section {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text("Søker …")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 88)
                                .accessibilityElement(children: .combine)
                            }
                            .listRowBackground(AppColors.surface)
                        case .failure(let message):
                            Section {
                                ContentUnavailableView {
                                    Label("Kunne ikke søke", systemImage: "wifi.exclamationmark")
                                } description: {
                                    Text(message)
                                } actions: {
                                    Button("Prøv igjen") {
                                        Task { await performSearch() }
                                    }
                                    Button("Skann strekkode") {
                                        showScanCamera = true
                                    }
                                }
                            }
                            .listRowBackground(AppColors.surface)
                        case .empty:
                            Section {
                                ContentUnavailableView.search(text: query)
                            }
                            .listRowBackground(AppColors.surface)
                        case .cachedResults, .results:
                            if case .cachedResults = searchState {
                                Section {
                                    Label("Viser lagrede treff. Nye varer kan kreve nett.", systemImage: "internaldrive")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .listRowBackground(AppColors.surface)
                            }
                            Section("Resultater") {
                                ForEach(searchResults) { product in
                                    rawRow(product: product, saveBeforeOpening: true)
                                }
                            }
                            .listRowBackground(AppColors.surface)
                        case .idle:
                            EmptyView()
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppColors.background)
                .tint(AppColors.action)
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.top, 8)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Søk")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.action)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.action)
                }
            }
            .task {
                await loadInitialData()
                searchFocused = true
            }
            .task(id: query) {
                await performSearch()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product, appState: appState) { payload in
                    dismiss()
                    onLogComplete(payload)
                }
            }
            .fullScreenCover(isPresented: $showScanCamera) {
                CameraView(onLogComplete: { _ in })
            }
        }
    }
    
    private func loadInitialData() async {
        curated = await productViewModel.rawFoodSuggestions()
        guard let userId = authViewModel.currentUser?.id else { return }
        recentProducts = await productViewModel.recentProducts(userId: userId, kind: .genericFood, limit: 6)
        favoriteProducts = await productViewModel.favoriteProducts(userId: userId, kind: .genericFood)
    }
    
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchState = .idle
            return
        }
        searchState = .loading
        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            let outcome = try await productViewModel.searchFoodsWithStatus(query: trimmed)
            guard !Task.isCancelled else { return }
            searchResults = outcome.items
            if outcome.items.isEmpty {
                searchState = .empty
            } else {
                switch outcome.source {
                case .localCache:
                    searchState = .cachedResults
                case .remote:
                    searchState = .results
                }
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            searchResults = []
            searchState = .failure("Sjekk forbindelsen og prøv igjen. Du kan fortsatt skanne eller bruke lagrede varer.")
        }
    }
    
    private func rawRow(item: MatvaretabellenProduct) -> some View {
        Button(action: {
            let product = toProduct(item: item)
            Task {
                guard let userId = authViewModel.currentUser?.id else { return }
                if await productViewModel.saveScannedProduct(product, userId: userId) {
                    await appState.refreshSyncStatus()
                } else {
                    appState.errorMessage = productViewModel.errorMessage
                }
            }
            selectedProduct = product
        }) {
            HStack(spacing: 12) {
                ProductThumbnailView(url: nil)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    if !preferencesViewModel.safeModeHideCalories {
                        Text("\(item.caloriesPer100g) kcal per 100 g · Matvaretabellen")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text("Matvaretabellen")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func rawRow(product: Product, saveBeforeOpening: Bool = false) -> some View {
        Button(action: {
            if saveBeforeOpening {
                Task {
                    guard let userId = authViewModel.currentUser?.id else { return }
                    if await productViewModel.saveScannedProduct(product, userId: userId) {
                        await appState.refreshSyncStatus()
                    } else {
                        appState.errorMessage = productViewModel.errorMessage
                    }
                }
            }
            selectedProduct = product
        }) {
            HStack(spacing: 12) {
                ProductThumbnailView(
                    url: product.imageUrl.flatMap(URL.init(string:)),
                    placeholderSystemImage: product.kind == .genericFood ? "fork.knife" : "shippingbox"
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                        .lineLimit(2)
                    if let brand = product.brand, !brand.isEmpty {
                        Text(brand)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                    Text(productContext(product))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }

    private func productContext(_ product: Product) -> String {
        let source = product.nutritionSource == .matvaretabellen ? "Matvaretabellen" : "Open Food Facts"
        guard !preferencesViewModel.safeModeHideCalories else { return source }
        return "\(product.caloriesPer100g) kcal per 100 g · \(source)"
    }
    
    private func toProduct(item: MatvaretabellenProduct) -> Product {
        Product(
            name: item.name,
            brand: item.brand,
            category: item.category,
            barcodeEan: nil,
            source: "matvaretabellen",
            kind: .genericFood,
            caloriesPer100g: item.caloriesPer100g,
            proteinGPer100g: item.proteinGPer100g,
            carbsGPer100g: item.carbsGPer100g,
            fatGPer100g: item.fatGPer100g,
            sugarGPer100g: item.sugarGPer100g,
            fiberGPer100g: item.fiberGPer100g,
            sodiumMgPer100g: item.sodiumMgPer100g,
            imageUrl: nil,
            standardPortions: nil,
            nutritionSource: .matvaretabellen,
            imageSource: .none,
            verificationStatus: .verified,
            confidenceScore: nil,
            isVerified: true
        )
    }
}
