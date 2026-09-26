import SwiftUI

struct ProductDetailView: View {
    let product: Product
    
    @ObservedObject var appState: AppState
    @EnvironmentObject var logViewModel: LogViewModel
    @EnvironmentObject var productViewModel: ProductViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var preferencesViewModel: PreferencesViewModel
    let onLogComplete: ((ReceiptPayload) -> Void)?
    @Environment(\.dismiss) var dismiss
    
    @State private var amountText: String = "100"
    @State private var isFavorite = false
    @State private var selectedMealType = "lunsj"
    @State private var showImagePreview = false
    @State private var showSourceInfo = false
    @State private var showNutritionImproving = true
    @State private var showPer100g = false
    @State private var isLogging = false
    @State private var logError: String?
    
    let mealTypes = ["Frokost", "Lunsj", "Middag", "Snacks"]
    let mealTypeKeys = ["frokost", "lunsj", "middag", "snacks"]
    
    var body: some View {
        let amount = parsedAmount ?? 0
        let nutrition = product.calculateNutrition(forAmount: Float(amount))
        let servings = compatibleServings

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
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Product Hero
                        heroView
                            .onTapGesture {
                                if product.imageUrl != nil {
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
                        
                        if showNutritionImproving, product.nutritionSource == .openFoodFacts, product.verificationStatus == .unverified {
                            EmptyView()
                        }
                        
                        // Per documented 100-unit basis (collapsible)
                        CardContainer {
                            DisclosureGroup(isExpanded: $showPer100g) {
                                VStack(spacing: 8) {
                                    if !preferencesViewModel.safeModeHideCalories {
                                        NutritionRowView(
                                            label: "Energi",
                                            value: "\(Int(product.caloriesPer100g)) kcal"
                                        )
                                    }
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
                                AmountInputRow(
                                    gramsText: amountTextBinding,
                                    unit: product.amountUnit.rawValue,
                                    placeholder: "0"
                                )
                                
                                if !servings.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(servings) { option in
                                                Button(action: {
                                                    setAmount(option.grams)
                                                }) {
                                                    Text(option.label)
                                                        .font(AppTypography.body)
                                                        .foregroundColor(AppColors.ink)
                                                        .lineLimit(1)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(AppColors.surface)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 16)
                                                                .stroke(AppColors.controlBorder, lineWidth: 1)
                                                        )
                                                        .cornerRadius(16)
                                                }
                                            }
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                
                                Text("Din mengde")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: summaryColumns, spacing: 8) {
                                    if !preferencesViewModel.safeModeHideCalories {
                                        SummaryPill(
                                            label: "Energi",
                                            value: "\(Int(nutrition.calories)) kcal",
                                            tintColor: AppColors.brand
                                        )
                                    }
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
                .disabled(amount <= 0.0001 || isLogging)
                .opacity(amount > 0.0001 && !isLogging ? 1.0 : 0.5)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }
                    .foregroundColor(AppColors.action)
            }
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                isFavorite = productViewModel.isFavorite(product, userId: userId)
            }
            if let userId = authViewModel.currentUser?.id,
               let lastUsed = preferencesViewModel.lastUsedAmount(for: product.id, userId: userId) {
                setAmount(lastUsed)
            } else if let suggested = compatibleServings.first(where: \.isDefaultSuggestion) {
                setAmount(suggested.grams)
            } else {
                setAmount(100)
            }
            selectedMealType = appState.selectedMealType
            showNutritionImproving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                showNutritionImproving = false
            }
        }
        .sheet(isPresented: $showImagePreview) {
            ImagePreviewView(imageUrl: product.imageUrl)
        }
        .sheet(isPresented: $showSourceInfo) {
            ProductSourceInfoView(product: product)
        }
    }

    private let amountRange: ClosedRange<Double> = 0...5000
    private let summaryColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    private let mealColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    private var compatibleServings: [ServingOption] {
        product.servings?.filter { $0.amountUnit == product.amountUnit } ?? []
    }

    private func logProduct() {
        guard !isLogging, let amount = parsedAmount, amount > 0 else { return }
        isLogging = true
        logError = nil
        Task {
            guard let userId = authViewModel.currentUser?.id else {
                logError = "Du må være logget inn for å lagre."
                isLogging = false
                return
            }
            guard await logViewModel.logFood(
                product: product,
                amountG: Float(amount),
                mealType: selectedMealType,
                userId: userId,
                date: appState.logSelectedDate
            ) else {
                logError = logViewModel.errorMessage ?? "Kunne ikke lagre på enheten. Prøv igjen."
                isLogging = false
                return
            }
            await logViewModel.loadTodaysSummary(userId: userId)
            await appState.refreshSyncStatus()
            preferencesViewModel.setLastUsedAmount(amount, for: product.id, userId: userId)
            HapticFeedbackService.shared.trigger(
                .loggingSuccess,
                isEnabled: preferencesViewModel.hapticsFeedbackEnabled
            )
            SoundFeedbackService.shared.play(
                .loggingSuccess,
                isEnabled: preferencesViewModel.soundFeedbackEnabled
            )
            onLogComplete?(
                ReceiptPayload(
                    product: product,
                    amountG: amount,
                    amountUnit: product.amountUnit,
                    mealType: selectedMealType,
                    loggedDate: appState.logSelectedDate
                )
            )
            isLogging = false
            dismiss()
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
    
    private func setAmount(_ amount: Double) {
        let clamped = min(max(amount, amountRange.lowerBound), amountRange.upperBound)
        amountText = clamped > 0 ? formatAmountText(clamped) : ""
    }

    private var amountTextBinding: Binding<String> {
        Binding(
            get: { amountText },
            set: { amountText = sanitizedAmountText($0) }
        )
    }

    private var parsedAmount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return min(max(value, amountRange.lowerBound), amountRange.upperBound)
    }

    private func sanitizedAmountText(_ text: String) -> String {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        let allowed = normalized.filter { $0.isNumber || $0 == "." }
        let parts = allowed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let sanitized = parts.count > 1 ? "\(parts[0]).\(parts[1])" : String(allowed)
        guard !sanitized.isEmpty, let value = Double(sanitized), value.isFinite else { return sanitized }
        let clamped = min(max(value, amountRange.lowerBound), amountRange.upperBound)
        return clamped == value ? sanitized : formatAmountText(clamped)
    }

    private func formatAmountText(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    private var heroView: some View {
        ProductHeroImageView(url: imageUrl, height: 220, cornerRadius: 18)
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
                
                if let imageUrl, let url = URL(string: imageUrl) {
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
                    infoRow(title: "Verifisering", value: verificationLabel(product.verificationStatus))
                    if let confidenceScore = product.confidenceScore {
                        infoRow(title: "Match-score", value: String(format: "%.2f", confidenceScore))
                    }
                    if let sourceUpdatedAt = product.sourceUpdatedAt {
                        infoRow(
                            title: "Sist oppdatert hos kilden",
                            value: sourceUpdatedAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    }

                    Text("Kilder vises for å være transparente uten å skape skam. Data kan være oppdatert eller uverifisert.")
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
            return "Verifisert"
        case .unverified:
            return "Uverifisert"
        case .suggestedMatch:
            return "Foreslått match"
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
