import SwiftUI

struct ProductDetailView: View {
    let product: Product
    
    @ObservedObject var appState: AppState
    let onLogComplete: ((ReceiptPayload) -> Void)?
    @Environment(\.dismiss) var dismiss
    @FocusState private var amountFieldFocused: Bool
    
    @State private var amountG: Double = 100
    @State private var amountText: String = "100"
    @State private var selectedUnit: WeightUnit = .grams
    @State private var isFavorite = false
    @State private var showingConfirmation = false
    @State private var selectedMealType = "lunsj"
    @State private var showImagePreview = false
    @State private var showSourceInfo = false
    @State private var useLastAmountNextTime = false
    @State private var lastUsedAmountG: Double?
    
    enum WeightUnit: String, CaseIterable {
        case grams = "g"
        case deciliters = "dl"
        
        func toGrams(_ value: Double) -> Double {
            switch self {
            case .grams:
                return value
            case .deciliters:
                return value * 100 // 1 dl ≈ 100g for most foods
            }
        }
        
        func fromGrams(_ grams: Double) -> Double {
            switch self {
            case .grams:
                return grams
            case .deciliters:
                return grams / 100
            }
        }
    }
    
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
                    
                    Button(action: { showSourceInfo = true }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 18))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.trailing, 8)
                    
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
                        
                        if product.nutritionSource == .openFoodFacts && product.verificationStatus == .unverified {
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
                                    NutritionRowView(
                                        label: "Energi",
                                        value: "\(Int(product.caloriesPer100g)) kcal"
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
                                Text("Mengde")
                                    .font(AppTypography.bodyEmphasis)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundColor(AppColors.ink)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(quickAmountChips, id: \.title) { chip in
                                            Button(action: {
                                                applyAmount(chip.grams, triggerHaptic: true)
                                                amountFieldFocused = false
                                            }) {
                                                Text(chip.title)
                                                    .font(AppTypography.body)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 8)
                                                    .background(AppColors.surface)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(AppColors.separator, lineWidth: 1)
                                                    )
                                                    .cornerRadius(16)
                                            }
                                        }
                                        
                                        Button(action: {
                                            amountFieldFocused = true
                                        }) {
                                            Text("Tilpass")
                                                .font(AppTypography.body)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(AppColors.chipFillSelected)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 16)
                                                        .stroke(AppColors.separator, lineWidth: 1)
                                                )
                                                .cornerRadius(16)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                HStack(spacing: 12) {
                                    TextField("Mengde", text: $amountText)
                                        .keyboardType(.decimalPad)
                                        .font(AppTypography.body)
                                        .padding(12)
                                        .background(AppColors.surface)
                                        .cornerRadius(8)
                                        .focused($amountFieldFocused)
                                        .onChange(of: amountText) {
                                            if let value = parseAmountText(amountText) {
                                                amountG = selectedUnit.toGrams(value)
                                                HapticFeedbackService.shared.trigger(
                                                    .stepperTap,
                                                    isEnabled: appState.hapticsFeedbackEnabled
                                                )
                                            }
                                        }
                                    
                                    Picker("Enhet", selection: $selectedUnit) {
                                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .frame(width: 80)
                                    .onChange(of: selectedUnit) {
                                        let converted = selectedUnit.fromGrams(amountG)
                                        amountText = formatAmountText(converted)
                                        HapticFeedbackService.shared.trigger(
                                            .stepperTap,
                                            isEnabled: appState.hapticsFeedbackEnabled
                                        )
                                    }
                                }
                                
                                HStack(spacing: 12) {
                                    inlineMacroValue(label: "kcal", value: "\(Int(nutrition.calories))")
                                    inlineMacroValue(label: "P", value: String(format: "%.1f", nutrition.protein))
                                    inlineMacroValue(label: "K", value: String(format: "%.1f", nutrition.carbs))
                                    inlineMacroValue(label: "F", value: String(format: "%.1f", nutrition.fat))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack {
                                    Text("Total")
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textSecondary)
                                    Spacer()
                                    Text("\(Int(amountG)) g")
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.ink)
                                }
                                .padding(.top, 8)
                                
                                if let lastUsedAmountG {
                                    Toggle(isOn: $useLastAmountNextTime) {
                                        Text("Bruk sist (\(Int(lastUsedAmountG)) g) neste gang")
                                            .font(AppTypography.body)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    .onChange(of: useLastAmountNextTime) {
                                        appState.setUseLastAmount(useLastAmountNextTime, for: product.id)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .padding(.horizontal)
                        
                        Spacer(minLength: 8)
                    }
                    .padding(.vertical)
                }
                
                // Add Button
                PrimaryButton(
                    title: "Legg til \(selectedMealType)",
                    systemImage: "plus.circle.fill",
                    action: { showingConfirmation = true }
                )
                .padding()
                .alert("Bekreft", isPresented: $showingConfirmation) {
                    Button("Legg til", action: {
                        Task {
                            await appState.logFood(
                                product: product,
                                amountG: Float(amountG),
                                mealType: selectedMealType
                            )
                            appState.setLastUsedAmount(amountG, for: product.id)
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
                                    amountG: amountG,
                                    nutrition: nutrition,
                                    mealType: selectedMealType
                                )
                            )
                        }
                    })
                    Button("Avbryt", role: .cancel) {}
                } message: {
                    Text("Legge til \(Int(amountG))g av \(product.name)?")
                }
            }
        }
        .onAppear {
            isFavorite = appState.isFavorite(product)
            lastUsedAmountG = appState.getLastUsedAmount(for: product.id)
            useLastAmountNextTime = appState.shouldUseLastAmount(for: product.id)
            let initialAmount = (useLastAmountNextTime ? lastUsedAmountG : nil) ?? 100
            applyAmount(initialAmount, triggerHaptic: false)
            selectedMealType = appState.selectedMealType
            HapticFeedbackService.shared.trigger(
                .barcodeDetected,
                isEnabled: appState.hapticsFeedbackEnabled
            )
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

    private var quickAmountChips: [(title: String, grams: Double)] {
        if let portions = product.standardPortions, !portions.isEmpty {
            return portions.map { (title: $0.label, grams: $0.grams) }
        }
        return [
            ("50g", 50.0),
            ("100g", 100.0),
            ("150g", 150.0),
            ("200g", 200.0)
        ]
    }
    
    private func applyAmount(_ grams: Double, triggerHaptic: Bool) {
        amountG = grams
        let unitValue = selectedUnit.fromGrams(grams)
        amountText = formatAmountText(unitValue)
        if triggerHaptic {
            HapticFeedbackService.shared.trigger(
                .stepperTap,
                isEnabled: appState.hapticsFeedbackEnabled
            )
        }
    }
    
    private func formatAmountText(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
    
    private func parseAmountText(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    private func inlineMacroValue(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)
            Text(value)
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.ink)
        }
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
