import SwiftUI

struct ProductDetailView: View {
    let product: Product
    @ObservedObject var appState: AppState
    @EnvironmentObject private var productViewModel: ProductViewModel
    let onLogComplete: ((ReceiptPayload) -> Void)?

    var body: some View {
        ProductDetailContent(product: product, appState: appState,
                             repository: productViewModel.barcodeRepository,
                             favorites: productViewModel.favoriteRepository,
                             onLogComplete: onLogComplete)
            .id(product.id)
    }
}

private struct ProductDetailContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showNutriScoreInfo = false
    @State private var showProcessingInfo = false
    @StateObject private var detailModel: ProductDetailViewModel
    private var product: Product { detailModel.product }

    init(product: Product, appState: AppState, repository: any BarcodeLookupRepository,
         favorites: any ProductFavoriteRepository,
         onLogComplete: ((ReceiptPayload) -> Void)?) {
        self.appState = appState
        self.onLogComplete = onLogComplete
        _detailModel = StateObject(wrappedValue: ProductDetailViewModel(product: product, repository: repository, favorites: favorites))
    }

    @ObservedObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onLogComplete: ((ReceiptPayload) -> Void)?
    @Environment(\.dismiss) var dismiss

    private var amountModel: AmountSelectionViewModel { detailModel.amountModel }
    private var isFavorite: Bool { detailModel.isFavorite }
    @State private var selectedMealType = "lunsj"
    @State private var showImagePreview = false
    @State private var showSourceInfo = false
    @State private var showNutritionImproving = true
    @State private var showPer100g = false
    private var isLogging: Bool { detailModel.isLogging }
    private var logError: String? { detailModel.logError }
    @State private var hasConfiguredAmount = false


    var body: some View {
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
                        .foregroundColor(AppColors.actionText)
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
                    .disabled(detailModel.isChangingFavorite)
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
                            .padding(.horizontal, 24)
                        if let brand = product.brand, !brand.isEmpty {
                            Text(brand)
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }


                        ProductLoggingSection(amountModel: amountModel, product: product, isLogging: isLogging,
                            selectedMealType: $selectedMealType, logDateLabel: logDateLabel,
                            nutritionForAmount: detailModel.nutrition)
                            .padding(.horizontal)

                        CardContainer {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Produktinformasjon")
                                .font(AppTypography.sectionTitle)
                                .foregroundColor(AppColors.ink)
                                DisclosureGroup(isExpanded: $showPer100g) {
                                    VStack(spacing: 8) {
                                        NutritionRowView(
                                        label: "Energi",
                                        value: "\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal"
                                        )
                                        NutritionRowView(
                                        label: "Protein",
                                        value: "\(String(format: "%.1f", locale: Locale(identifier: "nb_NO"), product.proteinGPer100g)) g"
                                        )
                                        NutritionRowView(
                                        label: "Karbohydrat",
                                        value: "\(String(format: "%.1f", locale: Locale(identifier: "nb_NO"), product.carbsGPer100g)) g"
                                        )
                                        NutritionRowView(
                                        label: "Fett",
                                        value: "\(String(format: "%.1f", locale: Locale(identifier: "nb_NO"), product.fatGPer100g)) g"
                                        )
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    Text("Næringsinnhold per 100 \(product.amountUnit.rawValue)")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundColor(AppColors.ink)
                                    .frame(minHeight: 44, alignment: .leading)
                                }
                                if detailModel.processingInfo != nil {
                                    Divider()
                                    Button { showNutriScoreInfo = true } label: {
                                        let layout = dynamicTypeSize.isAccessibilitySize
                                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                            : AnyLayout(HStackLayout(spacing: 12))
                                        layout {
                                            Text("Nutri-Score").font(AppTypography.bodyEmphasis)
                                            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
                                            HStack(spacing: 12) {
                                                if let info = detailModel.nutriScoreInfo {
                                                    NutriScoreLogo(info: info, width: dynamicTypeSize.isAccessibilitySize ? 88 : 80)
                                                } else {
                                                    Text("Ikke tilgjengelig").font(AppTypography.secondary)
                                                        .foregroundColor(AppColors.textSecondary)
                                                }
                                                Image(systemName: "chevron.right")
                                                .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                        .foregroundColor(AppColors.ink)
                                        .frame(maxWidth: .infinity, minHeight: 56)
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
                                                    .font(AppTypography.bodyEmphasis)
                                                Text(detailModel.processingPresentation?.isUltraProcessed == nil
                                                     ? "Ikke tilgjengelig"
                                                     : detailModel.processingPresentation?.status ?? "Ikke tilgjengelig")
                                                    .font(AppTypography.secondary)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            Spacer(minLength: 8)
                                            Image(systemName: "chevron.right")
                                            .foregroundColor(AppColors.textSecondary)
                                        }
                                        .foregroundColor(AppColors.ink)
                                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("productProcessingInfo")
                                    .accessibilityHint("Åpner forklaring, ingredienser og kilde")
                                }
                                if product.nutritionSource == .openFoodFacts || product.imageSource == .openFoodFacts || detailModel.canRefresh {
                                    Divider()
                                    VStack(alignment: .leading, spacing: 4) {
                                        if product.nutritionSource == .openFoodFacts || product.imageSource == .openFoodFacts,
                                           let sourceURL = URL(string: "https://world.openfoodfacts.org") {
                                            Link(destination: sourceURL) {
                                                Label("Data fra Open Food Facts", systemImage: "link")
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.actionText)
                                                    .frame(minHeight: 44, alignment: .leading)
                                            }
                                            .accessibilityHint("Åpner kilden i nettleseren")
                                        }

                                        if detailModel.canRefresh {
                                            if let fetchedAt = product.fetchedAt {
                                                Text("Sist hentet: \(fetchedAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))))")
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            Button {
                                                Task { await detailModel.refresh(manually: true) }
                                            } label: {
                                                Label(detailModel.isRefreshing ? "Henter produktdata …" : "Oppdater",
                                                      systemImage: "arrow.clockwise")
                                                    .font(AppTypography.secondaryEmphasis)
                                                    .frame(minWidth: 44, minHeight: 44)
                                            }
                                            .foregroundColor(AppColors.actionText)
                                            .accessibilityLabel(detailModel.isRefreshing ? "Henter produktdata" : "Hent oppdaterte produktdata")
                                            .disabled(detailModel.isRefreshing || isLogging)
                                            if let message = detailModel.refreshMessage {
                                                Text(message)
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.textSecondary)
                                                    .multilineTextAlignment(.leading)
                                                    .accessibilityIdentifier("productRefreshMessage")
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
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
                    .foregroundColor(AppColors.actionText)
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
                }

                ProductLogButton(amountModel: amountModel, selectedMealType: selectedMealType,
                    unit: product.amountUnit, isLogging: isLogging, onLog: logProduct)

            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }
                    .foregroundColor(AppColors.actionText)
            }
        }
        .task { await detailModel.refresh(manually: false) }
        .task(id: authViewModel.currentUser?.id) {
            await detailModel.loadFavorite(owner: authViewModel.currentUser?.id)
        }
        .onChange(of: detailModel.product.servings) { _, servings in
            amountModel.updateServings(servings ?? [])
        }
        .onAppear {
            guard !hasConfiguredAmount else { return }
            hasConfiguredAmount = true
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
                                  sourceURL: detailModel.processingSourceURL, fetchedAt: product.fetchedAt,
                                  excludedProteinValue: detailModel.excludedProteinValue)
        }
        .sheet(isPresented: $showProcessingInfo) {
            if let info = detailModel.processingInfo, let presentation = detailModel.processingPresentation {
                ProductProcessingInfoSheet(productName: product.name, info: info,
                                           sourceURL: detailModel.processingSourceURL,
                                           presentation: presentation, fetchedAt: product.fetchedAt)
            }
        }
    }

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
        ProductHeroImageView(localData: product.localImageData, url: imageUrl, height: 160, cornerRadius: 18)
    }

    private var imageUrl: URL? {
        guard let urlString = product.imageUrl else { return nil }
        return URL(string: urlString)
    }


    private func toggleFavorite() {
        Task {
            guard let userId = authViewModel.currentUser?.id else { return }
            if await detailModel.toggleFavorite(owner: userId) {
                HapticFeedbackService.shared.trigger(
                    .favoriteToggle,
                    isEnabled: preferencesViewModel.hapticsFeedbackEnabled
                )
                await appState.refreshSyncStatus()
            } else {
                appState.errorMessage = detailModel.favoriteError
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
                        .foregroundColor(AppColors.actionText)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                ProductPhotoView(localData: localData, url: imageUrl.flatMap(URL.init(string:)))
                    .padding(16)

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
                        infoRow(title: "Likhet med matvaren", value: String(format: "%.2f", locale: Locale(identifier: "nb_NO"), confidenceScore))
                    }
                    if let sourceUpdatedAt = product.sourceUpdatedAt {
                        infoRow(
                            title: "Sist oppdatert hos kilden",
                            value: sourceUpdatedAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO")))
                        )
                    }

                    if let fetchedAt = product.fetchedAt {
                        infoRow(title: "Sist hentet til enheten",
                                value: fetchedAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))))
                    }

                    Text("Her ser du hvor opplysningene kommer fra. Næringstallene kan inneholde feil eller være utdaterte.")
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, 8)

                    if product.nutritionSource == .openFoodFacts || product.imageSource == .openFoodFacts {
                        if let sourceURL = URL(string: "https://world.openfoodfacts.org") {
                            Link("Åpne Open Food Facts", destination: sourceURL)
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.actionText)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        if let licenseURL = URL(string: "https://opendatacommons.org/licenses/odbl/1-0/") {
                            Link("Database: Open Database License", destination: licenseURL)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.actionText)
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        if product.imageSource == .openFoodFacts,
                           let imageLicenseURL = URL(string: "https://creativecommons.org/licenses/by-sa/3.0/") {
                            Link("Bilder: CC BY-SA 3.0", destination: imageLicenseURL)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.actionText)
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
                        .foregroundColor(AppColors.actionText)
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

private struct ProductLoggingSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var amountModel: AmountSelectionViewModel
    let product: Product
    let isLogging: Bool
    @Binding var selectedMealType: String
    let logDateLabel: String
    let nutritionForAmount: (Double?) -> NutritionBreakdown
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        let selectedAmount = amountModel.amount
        let amount = selectedAmount ?? 0
        let nutrition = nutritionForAmount(selectedAmount)
        CardContainer {
            VStack(spacing: 12) {
                PortionAmountInput(model: amountModel)
                    .disabled(isLogging)

                Text("Næringsinnhold for din mengde")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 8) {
                    SummaryPill(
                        label: "Energi",
                        value: "\(NutritionDisplay.wholeCalories(nutrition.calories)) kcal",
                        tintColor: AppColors.energyTint
                    )
                    SummaryPill(
                        label: "Proteiner",
                        value: String(format: "%.1f g", locale: Locale(identifier: "nb_NO"), nutrition.protein),
                        tintColor: AppColors.macroProteinTint
                    )
                    SummaryPill(
                        label: "Karbohydrater",
                        value: String(format: "%.1f g", locale: Locale(identifier: "nb_NO"), nutrition.carbs),
                        tintColor: AppColors.macroCarbTint
                    )
                    SummaryPill(
                        label: "Fett",
                        value: String(format: "%.1f g", locale: Locale(identifier: "nb_NO"), nutrition.fat),
                        tintColor: AppColors.macroFatTint
                    )
                }

                if amount <= 0.0001 {
                    Text("Skriv inn mengde i \(product.amountUnit.spokenName)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }


                Divider()
                    .padding(.vertical, 4)

                Text("Måltid")
                    .font(AppTypography.bodyEmphasis)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(AppColors.ink)

                Label(logDateLabel, systemImage: "calendar")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(MealPresentation.all) { meal in
                        MealChip(
                            title: meal.title,
                            isSelected: selectedMealType == meal.key,
                            fillsWidth: true,
                            action: { selectedMealType = meal.key }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

            }
        }
    }
}

private struct ProductLogButton: View {
    @ObservedObject var amountModel: AmountSelectionViewModel
    let selectedMealType: String
    let unit: AmountUnit
    let isLogging: Bool
    let onLog: () -> Void
    var body: some View {
        let amount = amountModel.amount ?? 0
        let isEnabled = amountModel.isValid && !isLogging
        PrimaryButton(
            title: isLogging ? "Lagrer …" : "Legg til \(selectedMealType) · \(PortionDisplay.number(Double(amount))) \(unit.rawValue)",
            systemImage: "plus.circle.fill",
            action: onLog
        )
        .padding()
        .accessibilityIdentifier("product-log-save")
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}


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
    let presentation: ProductProcessingPresentation
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
                            Text(presentation.status).font(AppTypography.sectionTitle)
                            Text(presentation.explanation)
                                .font(AppTypography.secondary)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("Dette beskriver hvordan maten er bearbeidet. Nutri-Score gir informasjon om næringskvaliteten.")
                        .font(AppTypography.secondary)
                        .foregroundColor(AppColors.textSecondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hva bygger vurderingen på?")
                            .font(AppTypography.sectionTitle)
                            .accessibilityAddTraits(.isHeader)
                        Text(presentation.basis)
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
                        DisclosureGroup("Hva betyr NOVA?") {
                            Text("NOVA deler matvarer i fire grupper etter bearbeiding. Klassifiseringen bygger på registrerte produktopplysninger og kan være ufullstendig. NOVA beskriver ikke produktets samlede næringskvalitet.")
                        }
                        Text("Kilde: Open Food Facts")
                            .font(AppTypography.secondary)
                        if let fetchedAt {
                            Text("Sist hentet: \(fetchedAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))))")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        if let sourceURL {
                            Link("Se produktet hos Open Food Facts", destination: sourceURL)
                                .foregroundColor(AppColors.actionText)
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
            .navigationTitle("Ultraprosessert mat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lukk") { dismiss() }
                        .foregroundColor(AppColors.actionText)
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
    let excludedProteinValue: String?
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
                    if let calculation = info?.calculation {
                        NutriScoreCalculationView(calculation: calculation, excludedProteinValue: excludedProteinValue)
                    } else if info != nil {
                        Text("Detaljert beregningsgrunnlag ikke tilgjengelig.")
                            .foregroundColor(AppColors.textSecondary)
                    }
                    DisclosureGroup("Om Nutri-Score") {
                    Text("Nutri-Score oppsummerer produktets næringsprofil fra A til E og kan brukes til å sammenligne lignende produkter. Den beskriver ikke bearbeidingsgrad eller hele kostholdet.")
                    }
                    if let info {
                        Text(info.version.map { "Beregningsversjon: \($0)" } ?? "Beregningsversjon ikke oppgitt.")
                            .font(AppTypography.secondary)
                    }
                    Text("Registrerte opplysninger kan være ufullstendige. Karakteren kan avvike fra emballasjen dersom beregningsversjonen er forskjellig.")
                        .foregroundColor(AppColors.textSecondary)
                    if let fetchedAt {
                        Text("Sist hentet: \(fetchedAt.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "nb_NO"))))")
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    if let sourceURL {
                        Link("Se produktet hos Open Food Facts", destination: sourceURL)
                            .foregroundColor(AppColors.actionText)
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
                        .foregroundColor(AppColors.actionText)
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

private struct NutriScoreCalculationView: View {
    let calculation: NutriScoreCalculation
    let excludedProteinValue: String?
    @State private var showProteinExplanation = false
    private var presentation: NutriScoreCalculationPresentation {
        NutriScoreCalculationPresentation(calculation: calculation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(calculation.nutritionBasis.map { "Grunnlag per 100 \($0.amountUnit.rawValue)" } ?? "Beregningsgrunnlag")
                .font(AppTypography.sectionTitle)
            if calculation.preparation == "as_sold" {
                Text("For varen som solgt").font(AppTypography.secondary)
            } else if calculation.preparation == "prepared" {
                Text("For tilberedt vare").font(AppTypography.secondary)
            }
            if calculation.estimated {
                Text("Beregningen inneholder estimerte opplysninger.")
                    .foregroundColor(AppColors.textSecondary)
                    .accessibilityIdentifier("nutriscore-estimated")
            }
            Text("Boksene viser bidrag til Nutri-Score, ikke en daglig anbefaling.")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            componentGroup("Plusspoeng", components: calculation.positive,
                           points: calculation.positivePoints, maximum: calculation.positiveMaximum, tint: AppColors.nutritionPositiveContribution)
            componentGroup("Minuspoeng", components: calculation.negative,
                           points: calculation.negativePoints, maximum: calculation.negativeMaximum, tint: AppColors.nutritionNegativeContribution)
            if presentation.incomplete {
                Text("Ikke hele beregningsgrunnlaget kan vises.")
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }

    private func componentGroup(_ title: String, components: [NutriScoreComponent], points: Int?, maximum: Int?, tint: Color) -> some View {
        let rows = presentation.rows(components)
        return CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(title).font(AppTypography.sectionTitle).fixedSize()
                        Spacer(minLength: 12)
                        if let total = NutriScoreCalculationPresentation.points(points, maximum: maximum) {
                            Text(total).font(AppTypography.secondary).fixedSize()
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(AppTypography.sectionTitle)
                        if let total = NutriScoreCalculationPresentation.points(points, maximum: maximum) {
                            Text(total).font(AppTypography.secondary)
                        }
                    }
                }
                .accessibilityAddTraits(.isHeader)
                ForEach(rows) { row in
                    Divider()
                    NutriScoreComponentRow(row: row, tint: tint)
                }
                if title == "Plusspoeng", let explanation = presentation.proteinExplanation {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        ViewThatFits(in: .horizontal) {
                            HStack {
                                Text("Protein").font(AppTypography.bodyEmphasis)
                                Spacer(minLength: 12)
                                if let excludedProteinValue { Text(excludedProteinValue).font(AppTypography.secondary) }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Protein").font(AppTypography.bodyEmphasis)
                                if let excludedProteinValue { Text(excludedProteinValue).font(AppTypography.secondary) }
                            }
                        }
                        Button { showProteinExplanation = true } label: {
                            HStack(spacing: 8) {
                                Text("Teller ikke med i Nutri-Score")
                                    .font(AppTypography.caption)
                                Image(systemName: "info.circle")
                            }
                            .foregroundColor(AppColors.textSecondary)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("nutriscore-protein-explanation")
                        .accessibilityHint("Forklarer hvorfor protein ikke er medregnet")
                        .alert("Protein i Nutri-Score", isPresented: $showProteinExplanation) {
                            Button("Lukk", role: .cancel) { }
                        } message: { Text(explanation) }
                    }
                }
                if rows.isEmpty, title != "Plusspoeng" || presentation.proteinExplanation == nil {
                    Text("Komponentdetaljer ikke tilgjengelig.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NutriScoreComponentRow: View {
    let row: NutriScoreCalculationPresentation.Row
    let tint: Color
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title).font(AppTypography.bodyEmphasis)
                    Text(row.value).font(AppTypography.secondary)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(row.title).font(AppTypography.bodyEmphasis).fixedSize()
                        Spacer(minLength: 0)
                        Text(row.value).font(AppTypography.secondary).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title).font(AppTypography.bodyEmphasis)
                        Text(row.value).font(AppTypography.secondary)
                    }
                }
            }
            if let segments = row.segments {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 8, maximum: 12), spacing: 3)], alignment: .leading, spacing: 3) {
                    ForEach(0..<segments.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < segments.filled ? tint : AppColors.separator)
                            .frame(height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
            if let points = row.points {
                Text("\(points) poeng")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
}
