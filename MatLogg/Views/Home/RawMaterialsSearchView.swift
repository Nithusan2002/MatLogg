import SwiftUI

struct RawMaterialsSearchView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @FocusState private var searchFocused: Bool
    
    @State private var query = ""
    @State private var curated: [MatvaretabellenProduct] = []
    @State private var searchResults: [MatvaretabellenProduct] = []
    @State private var recentProducts: [Product] = []
    @State private var favoriteProducts: [Product] = []
    @State private var isLoading = false
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                CardContainer {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Søk råvarer", text: $query)
                            .font(AppTypography.body)
                            .focused($searchFocused)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, 16)
                
                if isLoading {
                    ProgressView()
                }
                
                List {
                    if query.isEmpty {
                        if !recentProducts.isEmpty {
                            Section("Sist brukt") {
                                ForEach(recentProducts) { product in
                                    rawRow(product: product)
                                }
                            }
                        }
                        
                        if !favoriteProducts.isEmpty {
                            Section("Favoritter") {
                                ForEach(favoriteProducts) { product in
                                    rawRow(product: product)
                                }
                            }
                        }
                        
                        Section("Vanlige råvarer") {
                            ForEach(curated, id: \.id) { item in
                                rawRow(item: item)
                            }
                        }
                    } else {
                        Section("Resultater") {
                            ForEach(searchResults, id: \.id) { item in
                                rawRow(item: item)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.top, 8)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Søk / Råvarer")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.brand)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                        .foregroundColor(AppColors.brand)
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
                ProductDetailView(product: product, appState: appState, onLogComplete: nil)
            }
        }
    }
    
    private func loadInitialData() async {
        curated = await appState.loadRawFoodSuggestions()
        recentProducts = await appState.loadRecentProducts(kind: .genericFood, limit: 6)
        favoriteProducts = await appState.loadFavoriteProducts(kind: .genericFood)
    }
    
    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }
        isLoading = true
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        let results = await appState.searchRawFoods(query: trimmed)
        if Task.isCancelled { return }
        searchResults = results
        isLoading = false
    }
    
    private func rawRow(item: MatvaretabellenProduct) -> some View {
        Button(action: {
            let product = toProduct(item: item)
            Task {
                await appState.saveScannedProduct(product)
            }
            selectedProduct = product
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    Text("\(item.caloriesPer100g) kcal per 100g")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    private func rawRow(product: Product) -> some View {
        Button(action: {
            selectedProduct = product
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    Text("\(product.caloriesPer100g) kcal per 100g")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .buttonStyle(.plain)
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
