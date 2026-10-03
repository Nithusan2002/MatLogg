import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @ObservedObject var appState: AppState
    @EnvironmentObject private var productViewModel: ProductViewModel
    let onLogComplete: ((ReceiptPayload) -> Void)?

    var body: some View {
        ProductDetailContent(product: product, appState: appState,
                             repository: productViewModel.barcodeRepository,
                             onLogComplete: onLogComplete)
            .id(product.id)
    }
}

private struct ProductDetailContent: View {
    @State private var showNutriScoreInfo = false
    @State private var showProcessingInfo = false
    @StateObject private var detailModel: ProductDetailViewModel
    private var product: Product { detailModel.product }

    init(product: Product, appState: AppState, repository: any BarcodeLookupRepository,
         onLogComplete: ((ReceiptPayload) -> Void)?) {
        self.appState = appState
        self.onLogComplete = onLogComplete
        _detailModel = StateObject(wrappedValue: ProductDetailViewModel(product: product, repository: repository))
        _amountModel = StateObject(wrappedValue: AmountSelectionViewModel(unit: product.amountUnit, servings: product.servings ?? []))
    }
    
    @ObservedObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onLogComplete: ((ReceiptPayload) -> Void)?
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var amountModel: AmountSelectionViewModel
    @State private var isFavorite = false
    @State private var selectedMealType = "lunsj"
    @State private var showImagePreview = false
    @State private var showSourceInfo = false
    @State private var showNutritionImproving = true
    @State private var showPer100g = false
    private var isLogging: Bool { detailModel.isLogging }
    private var logError: String? { detailModel.logError }
    @State private var hasConfiguredAmount = false
    
    let mealTypes = ["Frokost", "Lunsj", "Middag", "Snacks"]
    let mealTypeKeys = ["frokost", "lunsj", "middag", "snacks"]
    
    var body: some View {
        let amount = amountModel.amount ?? 0
        let nutrition = detailModel.nutrition(for: amountModel.amount)

        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Tilbake")
                        }
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.action)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    Spacer()
                    
                    if preferencesViewModel.showNutritionSource
                        || product.nutritionSource == .openFoodFacts
                        || product.imageSource == .openFoodFacts {
                        Button(action: { showSourceInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? AppColors.action : AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(isFavorite ? "Fjern fra favoritter" : "Legg til favoritt")
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Product Hero
                        heroView
                            .onTapGesture {
                                if product.imageUrl != nil || product.localImageData != nil {
                                    showImagePreview = true
                                }
                            }
                            .padding(.horizontal)
                        
                        Text(product.name)
                            .font(AppTypography.title)
                            .foregroundColor(AppColors.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 24)

                        if product.nutritionSource == .openFoodFacts || product.imageSource == .openFoodFacts,
                           let sourceURL = URL(string: "https://world.openfoodfacts.org") {
                            Link(destination: sourceURL) {
                                Label("Data fra Open Food Facts", systemImage: "link")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.action)
                            }
                            .accessibilityHint("Åpner kilden i nettleseren")
                        }
                        
                        if detailModel.canRefresh {
                            if let fetchedAt = product.fetchedAt {
                                Text("Sist hentet: \(fetchedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Button {
                                Task { await detailModel.refresh(manually: true) }
                            } label: {
                                Label(detailModel.isRefreshing ? "Henter produktdata …" : "Hent oppdaterte produktdata",
                                      systemImage: "arrow.clockwise")
                                    .font(AppTypography.body)
                                    .frame(minHeight: 44)
                            }
                            .foregroundColor(AppColors.action)
                            .disabled(detailModel.isRefreshing || isLogging)
                            if let message = detailModel.refreshMessage {
                                Text(message)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .accessibilityIdentifier("productRefreshMessage")
                            }
                        }

                        if showNutritionImproving, product.nutritionSource == .openFoodFacts, product.verificationStatus == .unverified {
                            EmptyView()
                        }
                        
                        // Per documented 100-unit basis (collapsible)
                        CardContainer {
                            DisclosureGroup(isExpanded: $showPer100g) {
                                VStack(spacing: 8) {
                                    NutritionRowView(
                                        label: "Energi",
                                        value: "\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal"
                                    )
                                    NutritionRowView(
                                        label: "Protein",
                                        value: "\(String(format: "%.1f", product.proteinGPer100g)) g"
                                    )
                                    NutritionRowView(
                                        label: "Karbohydrat",
                                        value: "\(String(format: "%.1f", product.carbsGPer100g)) g"
                                    )
                                    NutritionRowView(
                                        label: "Fett",
                                        value: "\(String(format: "%.1f", product.fatGPer100g)) g"
                                    )
                                }
                                .padding(.top, 8)
                            } label: {
                                Text("Vis per 100 \(product.amountUnit.rawValue)")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                            }
                        }
                        .padding(.horizontal)
                        
                        if let info = detailModel.processingInfo {
                            CardContainer {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Produktinformasjon")
                                        .font(AppTypography.sectionTitle)
                                        .foregroundColor(AppColors.ink)
                                    Button { showNutriScoreInfo = true } label: {
                                        HStack(spacing: 12) {
                                            Text("Nutri-Score").font(AppTypography.bodyEmphasis)
                                            Spacer(minLength: 8)
                                            if let info = detailModel.nutriScoreInfo {
                                                NutriScoreLogo(info: info, width: 104)
                                            } else {
                                                Text("Ikke tilgjengelig").font(AppTypography.secondary)
                                            }
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.textSecondary)
                                        }
                                        .foregroundColor(AppColors.ink)
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("productNutriScoreInfo")
                                    .accessibilityHint("Åpner forklaring og kilde")
                                    Divider()
                                Button { showProcessingInfo = true } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("Bearbeidingsgrad")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.textSecondary)
                                            Text(info.groupTitle)
                                                .font(AppTypography.bodyEmphasis)
                                                .foregroundColor(AppColors.ink)
                                        }
                                        Spacer(minLength: 8)
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("productProcessingInfo")
                                .accessibilityHint("Åpner forklaring, ingredienser og kilde")
                                }
                            }
                            .padding(.horizontal)
                        }

                        Divider()
                            .padding(.horizontal)
                        
                        CardContainer {
                            VStack(spacing: 12) {
                                Text("Måltid")
                                    .font(AppTypography.bodyEmphasis)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(AppColors.ink)

                                Label(logDateLabel, systemImage: "calendar")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: mealColumns, spacing: 8) {
                                    ForEach(0..<mealTypes.count, id: \.self) { index in
                                        MealChip(
                                            title: mealTypes[index],
                                            isSelected: selectedMealType == mealTypeKeys[index],
                                            action: { selectedMealType = mealTypeKeys[index] }
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Amount Input Section
                        CardContainer {
                            VStack(spacing: 12) {
                                PortionAmountInput(model: amountModel)
                                    .disabled(isLogging)

                                Text("Din mengde")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: summaryColumns, spacing: 8) {
                                    SummaryPill(
                                        label: "Energi",
                                        value: "\(NutritionDisplay.wholeCalories(nutrition.calories)) kcal",
                                        tintColor: AppColors.brand
                                    )
                                    SummaryPill(
                                        label: "Proteiner",
                                        value: String(format: "%.1f g", nutrition.protein),
                                        tintColor: AppColors.macroProteinTint
                                    )
                                    SummaryPill(
                                        label: "Karbohydrater",
                                        value: String(format: "%.1f g", nutrition.carbs),
                                        tintColor: AppColors.macroCarbTint
                                    )
                                    SummaryPill(
                                        label: "Fett",
                                        value: String(format: "%.1f g", nutrition.fat),
                                        tintColor: AppColors.macroFatTint
                                    )
                                }
                                
                                if amount <= 0.0001 {
                                    Text("Skriv inn mengde i \(product.amountUnit.spokenName)")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                    }
                    .padding(.vertical)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Add Button
                if let logError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(logError)
                        Spacer()
                        Button("Prøv igjen", action: logProduct)
                            .font(AppTypography.captionEmphasis)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.action)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                }

                PrimaryButton(
                    title: isLogging ? "Lagrer …" : "Legg til \(selectedMealType)",
                    systemImage: "plus.circle.fill",
                    action: logProduct
                )
                .padding()
                .accessibilityIdentifier("product-log-save")
                .disabled(!amountModel.isValid || isLogging)
                .opacity(amountModel.isValid && !isLogging ? 1.0 : 0.5)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }
                    .foregroundColor(AppColors.action)
            }
        }
        .task { await detailModel.refresh(manually: false) }
        .onChange(of: detailModel.product.servings) { _, servings in
            amountModel.updateServings(servings ?? [])
        }
        .onAppear {
            guard !hasConfiguredAmount else { return }
            hasConfiguredAmount = true
            if let userId = authViewModel.currentUser?.id {
                isFavorite = productViewModel.isFavorite(product, userId: userId)
            }
            if let userId = authViewModel.currentUser?.id,
               let lastUsed = preferencesViewModel.lastUsedAmount(for: product.id, userId: userId) {
                amountModel.restore(amount: lastUsed, portion: preferencesViewModel.lastUsedPortion(for: product.id, userId: userId))
            } else if let suggested = amountModel.servings.first(where: \.isDefaultSuggestion) {
                amountModel.select(suggested)
            } else {
                amountModel.restore(amount: 100, portion: nil)
            }
            selectedMealType = appState.selectedMealType
            showNutritionImproving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                showNutritionImproving = false
            }
        }
        .sheet(isPresented: $showImagePreview) {
            ImagePreviewView(imageUrl: product.imageUrl, localData: product.localImageData)
        }
        .sheet(isPresented: $showSourceInfo) {
            ProductSourceInfoView(product: product)
        }
        .sheet(isPresented: $showNutriScoreInfo) {
            ProductNutriScoreSheet(productName: product.name, info: detailModel.nutriScoreInfo,
                                  sourceURL: detailModel.processingSourceURL, fetchedAt: product.fetchedAt)
        }
        .sheet(isPresented: $showProcessingInfo) {
            if let info = detailModel.processingInfo {
                ProductProcessingInfoSheet(productName: product.name, info: info,
                                           sourceURL: detailModel.processingSourceURL)
            }
        }
    }

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    private let mealColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private func logProduct() {
        let mealType = selectedMealType
        let loggedDate = appState.logSelectedDate
        Task {
            let success = await detailModel.log(amount: amountModel) { product, amount, portion in
                guard let userId = authViewModel.currentUser?.id else { return false }
                guard await logViewModel.logFood(product: product, amountG: Float(amount),
                    mealType: mealType, userId: userId, date: loggedDate, portionSelection: portion) else { return false }
                preferencesViewModel.setLastUsedAmount(amount, for: product.id, userId: userId)
                preferencesViewModel.setLastUsedPortion(portion, for: product.id, userId: userId)
                HapticFeedbackService.shared.trigger(.loggingSuccess, isEnabled: preferencesViewModel.hapticsFeedbackEnabled)
                SoundFeedbackService.shared.play(.loggingSuccess, isEnabled: preferencesViewModel.soundFeedbackEnabled)
                onLogComplete?(ReceiptPayload(product: product, amountG: amount,
                    amountUnit: product.amountUnit, mealType: mealType, loggedDate: loggedDate, portionSelection: portion))
                return true
            }
            guard success else { return }
            dismiss()
            if let userId = authViewModel.currentUser?.id {
                await logViewModel.loadTodaysSummary(userId: userId)
                await appState.refreshSyncStatus()
            }
        }
    }

    private var logDateLabel: String {
        let date = appState.logSelectedDate
        if Calendar.current.isDateInToday(date) { return "Logges i dag" }
        if Calendar.current.isDateInYesterday(date) { return "Logges i går" }
        if Calendar.current.isDateInTomorrow(date) { return "Logges i morgen" }
        let formattedDate = date.formatted(
            .dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO"))
        )
        return "Logges \(formattedDate)"
    }
    
    @ViewBuilder private var heroView: some View {
        if let data = product.localImageData, let image = UIImage(data: data) {
            ProductHeroImageView(image: image, height: 220, cornerRadius: 18)
        } else {
            ProductHeroImageView(url: imageUrl, height: 220, cornerRadius: 18)
        }
    }
    
    private var imageUrl: URL? {
        guard let urlString = product.imageUrl else { return nil }
        return URL(string: urlString)
    }
    
    
    private func toggleFavorite() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await productViewModel.toggleFavorite(product, userId: userId) {
                isFavorite.toggle()
                HapticFeedbackService.shared.trigger(
                    .favoriteToggle,
                    isEnabled: preferencesViewModel.hapticsFeedbackEnabled
                )
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = productViewModel.errorMessage
            }
        }
    }
}

struct ImagePreviewView: View {
    let imageUrl: String?
    var localData: Data? = nil
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.action)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                Spacer()
                
                if let localData, let image = UIImage(data: localData) {
                    Image(uiImage: image).resizable().scaledToFit().padding(16)
                } else if let imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .padding(16)
                                .scaleEffect(scale)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let delta = value / lastScale
                                            lastScale = value
                                            scale = min(max(scale * delta, 1.0), 3.0)
                                        }
                                        .onEnded { _ in
                                            lastScale = 1.0
                                        }
                                )
                        case .failure:
                            Text("Bilde ikke tilgjengelig")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Text("Bilde ikke tilgjengelig")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
        }
    }
}

struct ProductSourceInfoView: View {
    let product: Product
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    infoRow(title: "Næringskilde", value: sourceLabel(product.nutritionSource))
                    infoRow(title: "Bildekilde", value: sourceLabel(product.imageSource))
                    infoRow(title: "Kontroll av næringstall", value: verificationLabel(product.verificationStatus))
                    if let confidenceScore = product.confidenceScore {
                        infoRow(title: "Likhet med matvaren", value: String(format: "%.2f", confidenceScore))
                    }
                    if let sourceUpdatedAt = product.sourceUpdatedAt {
                        infoRow(
                            title: "Sist oppdatert hos kilden",
                            value: sourceUpdatedAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    if let fetchedAt = product.fetchedAt {
                        infoRow(title: "Sist hentet til enheten",
                                value: fetchedAt.formatted(date: .abbreviated, time: .omitted))
                    }

                    Text("Her ser du hvor opplysningene kommer fra. Næringstallene kan inneholde feil eller være utdaterte.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 8)

                    if product.nutritionSource == .openFoodFacts || product.imageSource == .openFoodFacts {
                        if let sourceURL = URL(string: "https://world.openfoodfacts.org") {
                            Link("Åpne Open Food Facts", destination: sourceURL)
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.action)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        if let licenseURL = URL(string: "https://opendatacommons.org/licenses/odbl/1-0/") {
                            Link("Database: Open Database License", destination: licenseURL)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.action)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        if product.imageSource == .openFoodFacts,
                           let imageLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/3.0/") {
                            Link("Bilder: CC BY-SA 3.0", destination: imageLicenseURL)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.action)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Kilder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .foregroundColor(AppColors.action)
                }
            }
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
        }
        .padding(12)
        .background(AppColors.surface)
        .cornerRadius(12)
    }
    
    private func sourceLabel(_ source: NutritionSource) -> String {
        switch source {
        case .matvaretabellen:
            return "Matvaretabellen"
        case .openFoodFacts:
            return "Open Food Facts"
        case .user:
            return "Bruker"
        }
    }
    
    private func sourceLabel(_ source: ImageSource) -> String {
        switch source {
        case .openFoodFacts:
            return "Open Food Facts"
        case .user:
            return "Bruker"
        case .none:
            return "Ingen"
        }
    }
    
    private func verificationLabel(_ status: VerificationStatus) -> String {
        switch status {
        case .verified:
            return "Kontrollert"
        case .unverified:
            return "Ikke kontrollert"
        case .suggestedMatch:
            return "Foreslått treff"
        }
    }
}


// MARK: - Supporting Views

struct NutritionRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(AppTypography.body)
                .foregroundColor(AppColors.textSecondary)
            Spacer()
            Text(value)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.background)
        .cornerRadius(8)
    }
}

#Preview {
    let mockProduct = Product(
        id: UUID(),
        name: "Test Produkt",
        brand: nil,
        category: nil,
        barcodeEan: "1234567890",
        source: "manual",
        kind: .packaged,
        caloriesPer100g: 200,
        proteinGPer100g: 10,
        carbsGPer100g: 20,
        fatGPer100g: 8,
        sugarGPer100g: nil,
        fiberGPer100g: nil,
        sodiumMgPer100g: nil,
        imageUrl: nil,
        nutritionSource: .user,
        imageSource: .none,
        verificationStatus: .unverified,
        isVerified: false,
        createdAt: Date()
    )
    
    let appState = AppState()
    
    ProductDetailView(product: mockProduct, appState: appState, onLogComplete: nil)
        .environmentObject(LogViewModel(repository: DatabaseService()))
        .environmentObject(ProductViewModel(repository: DatabaseService()))
        .environmentObject(AuthViewModel())
        .environmentObject(PreferencesViewModel())
}

/// Presentation only: opening this sheet performs no catalog lookup.
private struct ProductProcessingInfoSheet: View {
    let productName: String
    let info: ProductProcessingInfo
    let sourceURL: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(productName)
                        .font(AppTypography.title)
                        .accessibilityAddTraits(.isHeader)
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(info.groupTitle).font(AppTypography.sectionTitle)
                            Text(info.classificationText ?? "Open Food Facts har ingen tilgjengelig klassifisering for dette produktet.")
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Grunnlag for klassifiseringen")
                            .font(AppTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        if info.markerNames.isEmpty {
                            Text("Forklarende grunnlag ikke tilgjengelig.")
                        } else {
                            ForEach(info.markerNames, id: \.self) { name in
                                Text(name.capitalized)
                            }
                            if info.hasUntranslatedMarkers {
                                Text("Bare tilgjengelig, forståelig grunnlag vises.")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ingredienser")
                            .font(AppTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text(info.ingredients ?? "Ingrediensliste ikke tilgjengelig.")
                        Text("Kontroller emballasjen hvis opplysningene avviker.")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Om NOVA")
                            .font(AppTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text("NOVA deler matvarer i fire grupper etter bearbeiding. Klassifiseringen bygger på registrerte produktopplysninger og kan være ufullstendig. NOVA beskriver ikke produktets samlede næringskvalitet.")
                        if let sourceURL {
                            Link("Se produktet hos Open Food Facts", destination: sourceURL)
                                .foregroundColor(AppColors.action)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                    }
                }
                .font(AppTypography.body)
                .foregroundColor(AppColors.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.background)
            .navigationTitle("Bearbeidingsgrad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.action)
                        .accessibilityIdentifier("processing-info-close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct ProductNutriScoreSheet: View {
    let productName: String
    let info: ProductNutriScoreInfo?
    let sourceURL: URL?
    let fetchedAt: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(productName)
                        .font(AppTypography.title)
                        .accessibilityAddTraits(.isHeader)
                    CardContainer {
                        VStack(alignment: .leading, spacing: 8) {
                            if let info {
                                NutriScoreLogo(info: info, width: 180)
                            } else {
                                Text("Nutri-Score ikke tilgjengelig")
                                    .font(AppTypography.sectionTitle)
                            }
                            Text(info == nil
                                 ? "Open Food Facts har ingen tilgjengelig karakter for dette produktet."
                                 : "Oppgitt av Open Food Facts.")
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Nutri-Score oppsummerer produktets næringsprofil fra A til E og kan brukes til å sammenligne lignende produkter. Den beskriver ikke bearbeidingsgrad eller hele kostholdet.")
                    if let info {
                        Text(info.version.map { "Beregningsversjon: \($0)" } ?? "Beregningsversjon ikke oppgitt.")
                            .font(AppTypography.secondary)
                    }
                    Text("Registrerte opplysninger kan være ufullstendige. Karakteren kan avvike fra emballasjen dersom beregningsversjonen er forskjellig.")
                        .foregroundColor(AppColors.textSecondary)
                    if let fetchedAt {
                        Text("Sist hentet: \(fetchedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let sourceURL {
                        Link("Se produktet hos Open Food Facts", destination: sourceURL)
                            .foregroundColor(AppColors.action)
                            .frame(minHeight: 44, alignment: .leading)
                    }
                }
                .font(AppTypography.body)
                .foregroundColor(AppColors.ink)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppColors.background)
            .navigationTitle("Nutri-Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.action)
                        .accessibilityIdentifier("nutriscore-info-close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

/// Official vector artwork bundled for offline use; original colors are preserved.
private struct NutriScoreLogo: View {
    let info: ProductNutriScoreInfo
    let width: CGFloat

    var body: some View {
        if let assetName = info.imageAssetName {
            Image(assetName)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: width)
                .accessibilityLabel("Nutri-Score \(info.grade)")
                .accessibilityIdentifier("nutriscore-logo")
        } else {
            Text("Nutri-Score \(info.grade)")
                .font(AppTypography.bodyEmphasis)
        }
    }
}
