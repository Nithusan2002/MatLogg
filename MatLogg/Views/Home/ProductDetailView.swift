import SwiftUI

struct ProductDetailView: View {
    let product: Product
    
    @ObservedObject var appState: AppState
    let onLogComplete: ((ReceiptPayload) -> Void)?
    @Environment(\.dismiss) var dismiss
    
    @State private var amountG: Int = 100
    @State private var amountText: String = "100"
    @State private var isFavorite = false
    @State private var showingConfirmation = false
    @State private var selectedMealType = "lunsj"
    @State private var showImagePreview = false
    @State private var showSourceInfo = false
    @State private var showNutritionImproving = true
    @State private var useLastAmountNextTime = false
    @State private var lastUsedAmountG: Int?
    
    var nutrition: NutritionBreakdown {
        product.calculateNutrition(forGrams: Float(amountG))
    }
    
    let mealTypes = ["Frokost", "Lunsj", "Middag", "Snacks"]
    let mealTypeKeys = ["frokost", "lunsj", "middag", "snacks"]
    
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
                        .foregroundColor(AppColors.brand)
                    }
                    Spacer()
                    
                    if appState.showNutritionSource {
                        Button(action: { showSourceInfo = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 18))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.trailing, 8)
                    }
                    
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? AppColors.brand : AppColors.textSecondary)
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
                        
                        if showNutritionImproving, product.nutritionSource == .openFoodFacts, product.verificationStatus == .unverified {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Forbedrer næringsdata…")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        // Nutrition Facts - Per 100g
                        CardContainer {
                            VStack(spacing: 12) {
                                Text("Næringsinnhold per 100g")
                                    .font(AppTypography.bodyEmphasis)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(AppColors.ink)
                                
                                VStack(spacing: 8) {
                                    if !appState.safeModeHideCalories {
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
                                
                                HStack(spacing: 8) {
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
                                    gramsText: $amountText,
                                    placeholder: "0",
                                    onFocus: {
                                        HapticFeedbackService.shared.trigger(
                                            .stepperTap,
                                            isEnabled: appState.hapticsFeedbackEnabled
                                        )
                                    }
                                )
                                
                                Text("Din mengde")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                LazyVGrid(columns: summaryColumns, spacing: 8) {
                                    if !appState.safeModeHideCalories {
                                        SummaryPill(
                                            label: "kcal",
                                            value: "\(Int(nutrition.calories))",
                                            backgroundColor: AppColors.brand
                                        )
                                    }
                                    SummaryPill(
                                        label: "Proteiner",
                                        value: String(format: "%.1f g", nutrition.protein),
                                        backgroundColor: AppColors.macroProteinTint
                                    )
                                    SummaryPill(
                                        label: "Karbohydrater",
                                        value: String(format: "%.1f g", nutrition.carbs),
                                        backgroundColor: AppColors.macroCarbTint
                                    )
                                    SummaryPill(
                                        label: "Fett",
                                        value: String(format: "%.1f g", nutrition.fat),
                                        backgroundColor: AppColors.macroFatTint
                                    )
                                }
                                
                                if amountG == 0 {
                                    Text("Skriv inn mengde i gram")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                if let lastUsedAmountG {
                                    Toggle(isOn: $useLastAmountNextTime) {
                                        Text("Bruk sist (\(lastUsedAmountG) g) neste gang")
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .onChange(of: useLastAmountNextTime) { _, newValue in
                                        appState.setUseLastAmount(newValue, for: product.id)
                                    }
                                }
                            }
                        }
                        .onChange(of: amountText) { _, newValue in
                            updateAmountFromText(newValue)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical)
                }
                .scrollDismissesKeyboard(.interactively)
                
                // Add Button
                PrimaryButton(
                    title: "Legg til \(selectedMealType)",
                    systemImage: "plus.circle.fill",
                    action: { showingConfirmation = true }
                )
                .padding()
                .disabled(amountG <= 0)
                .opacity(amountG > 0 ? 1.0 : 0.5)
                .alert("Bekreft", isPresented: $showingConfirmation) {
                    Button("Legg til", action: {
                        Task {
                            await appState.logFood(
                                product: product,
                                amountG: Float(amountG),
                                mealType: selectedMealType
                            )
                            appState.setLastUsedAmount(Double(amountG), for: product.id)
                            lastUsedAmountG = amountG
                            HapticFeedbackService.shared.trigger(
                                .loggingSuccess,
                                isEnabled: appState.hapticsFeedbackEnabled
                            )
                            SoundFeedbackService.shared.play(
                                .loggingSuccess,
                                isEnabled: appState.soundFeedbackEnabled
                            )
                            onLogComplete?(
                                ReceiptPayload(
                                    product: product,
                                    amountG: Double(amountG),
                                    nutrition: nutrition,
                                    mealType: selectedMealType
                                )
                            )
                        }
                    })
                    Button("Avbryt", role: .cancel) {}
                } message: {
                    Text("Legge til \(amountG) g av \(product.name)?")
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Ferdig") { hideKeyboard() }
                    .foregroundColor(AppColors.brand)
            }
        }
        .onAppear {
            isFavorite = appState.isFavorite(product)
            if let lastAmount = appState.getLastUsedAmount(for: product.id) {
                lastUsedAmountG = Int(lastAmount)
            }
            useLastAmountNextTime = appState.shouldUseLastAmount(for: product.id)
            let initialAmount = (useLastAmountNextTime ? lastUsedAmountG : nil) ?? 100
            setAmount(initialAmount)
            selectedMealType = appState.selectedMealType
            HapticFeedbackService.shared.trigger(
                .barcodeDetected,
                isEnabled: appState.hapticsFeedbackEnabled
            )
            showNutritionImproving = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                showNutritionImproving = false
            }
        }
        .sheet(isPresented: $showImagePreview) {
            ImagePreviewView(imageUrl: product.imageUrl)
        }
        .sheet(isPresented: $showSourceInfo) {
            ProductSourceInfoView(
                nutritionSource: product.nutritionSource,
                imageSource: product.imageSource,
                verificationStatus: product.verificationStatus,
                confidenceScore: product.confidenceScore
            )
        }
    }

    private let amountRange: ClosedRange<Int> = 0...5000
    private let summaryColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    private func setAmount(_ grams: Int) {
        let clamped = min(max(grams, amountRange.lowerBound), amountRange.upperBound)
        amountG = clamped
        amountText = clamped > 0 ? String(clamped) : ""
    }
    
    private func updateAmountFromText(_ text: String) {
        let sanitized = text.filter { $0.isNumber }
        if sanitized != text {
            amountText = sanitized
            return
        }
        
        guard !sanitized.isEmpty, let value = Int(sanitized) else {
            amountG = 0
            return
        }
        
        let clamped = min(max(value, amountRange.lowerBound), amountRange.upperBound)
        if clamped != value {
            amountText = String(clamped)
        }
        amountG = clamped
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
            await appState.toggleFavorite(product: product)
        }
        isFavorite.toggle()
        HapticFeedbackService.shared.trigger(
            .favoriteToggle,
            isEnabled: appState.hapticsFeedbackEnabled
        )
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
                        .foregroundColor(AppColors.brand)
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
    let nutritionSource: NutritionSource
    let imageSource: ImageSource
    let verificationStatus: VerificationStatus
    let confidenceScore: Double?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(title: "Næringskilde", value: sourceLabel(nutritionSource))
                infoRow(title: "Bildekilde", value: sourceLabel(imageSource))
                infoRow(title: "Verifisering", value: verificationLabel(verificationStatus))
                if let confidenceScore {
                    infoRow(title: "Match-score", value: String(format: "%.2f", confidenceScore))
                }
                
                Text("Kilder vises for å være transparente uten å skape skam. Data kan være oppdatert eller uverifisert.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding(16)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Kilder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Ferdig") { dismiss() }
                        .foregroundColor(AppColors.brand)
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
}
