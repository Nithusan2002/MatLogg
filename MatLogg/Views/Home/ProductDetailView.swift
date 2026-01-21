import SwiftUI

struct ProductDetailView: View {
    let product: Product
    
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var amountG: Double = 100
    @State private var isFavorite = false
    @State private var selectedPortion: String = "100g"
    @State private var showingConfirmation = false
    @State private var showReceipt = false
    
    let standardPortions = [
        ("50g", 50.0),
        ("100g", 100.0),
        ("150g", 150.0),
        ("200g", 200.0),
        ("250g", 250.0),
        ("Annen", 0.0)
    ]
    
    var nutrition: NutritionBreakdown {
        product.calculateNutrition(forGrams: Float(amountG))
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Tilbake")
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                    }
                    Spacer()
                    
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(isFavorite ? .red : .gray)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Product Image Placeholder
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(height: 200)
                            
                            VStack(spacing: 8) {
                                Image(systemName: "box.2")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                Text(product.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Nutrition Facts - Per 100g
                        VStack(spacing: 12) {
                            Text("Næringsinnhold per 100g")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                NutritionRowView(
                                    label: "Energi",
                                    value: "\(Int(product.caloriesPer100g)) kcal",
                                    color: .orange
                                )
                                NutritionRowView(
                                    label: "Protein",
                                    value: "\(String(format: "%.1f", product.proteinGPer100g)) g",
                                    color: .red
                                )
                                NutritionRowView(
                                    label: "Karbohydrat",
                                    value: "\(String(format: "%.1f", product.carbsGPer100g)) g",
                                    color: .blue
                                )
                                NutritionRowView(
                                    label: "Fett",
                                    value: "\(String(format: "%.1f", product.fatGPer100g)) g",
                                    color: .yellow
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Amount Selection
                        VStack(spacing: 16) {
                            Text("Velg mengde")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            // Standard Portions
                            VStack(spacing: 8) {
                                ForEach(standardPortions, id: \.0) { label, grams in
                                    if grams > 0 {
                                        Button(action: {
                                            amountG = grams
                                            selectedPortion = label
                                            HapticFeedbackService.shared.trigger(.stepperTap)
                                        }) {
                                            HStack {
                                                Text(label)
                                                    .font(.body)
                                                Spacer()
                                                if selectedPortion == label {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                } else {
                                                    Circle()
                                                        .stroke(Color.gray, lineWidth: 1)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Custom Amount Slider
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Annen mengde")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(Int(amountG)) g")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                }
                                
                                Slider(value: $amountG, in: 10...1000, step: 5)
                                    .onChange(of: amountG) { _ in
                                        selectedPortion = "Annen"
                                        HapticFeedbackService.shared.trigger(.stepperTap)
                                    }
                            }
                            .padding(.horizontal)
                        }
                        
                        Divider()
                            .padding(.horizontal)
                        
                        // Total Nutrition Preview
                        VStack(spacing: 12) {
                            Text("For denne mengden (\(Int(amountG)) g)")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                NutritionRowView(
                                    label: "Energi",
                                    value: "\(Int(nutrition.calories)) kcal",
                                    color: .orange
                                )
                                NutritionRowView(
                                    label: "Protein",
                                    value: "\(String(format: "%.1f", nutrition.protein)) g",
                                    color: .red
                                )
                                NutritionRowView(
                                    label: "Karbohydrat",
                                    value: "\(String(format: "%.1f", nutrition.carbs)) g",
                                    color: .blue
                                )
                                NutritionRowView(
                                    label: "Fett",
                                    value: "\(String(format: "%.1f", nutrition.fat)) g",
                                    color: .yellow
                                )
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom)
                    }
                    .padding(.vertical)
                }
                
                // Add Button
                Button(action: { showingConfirmation = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Legg til \(appState.selectedMealType.rawValue.lowercased())")
                            .fontWeight(.semibold)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding()
                .alert("Bekreft", isPresented: $showingConfirmation) {
                    Button("Legg til", action: {
                        appState.logFood(
                            product: product,
                            amountG: Float(amountG),
                            mealType: appState.selectedMealType
                        )
                        HapticFeedbackService.shared.trigger(.loggingSuccess)
                        SoundFeedbackService.shared.play(.loggingSuccess)
                        showReceipt = true
                    })
                    Button("Avbryt", role: .cancel) {}
                } message: {
                    Text("Legge til \(Int(amountG))g av \(product.name)?")
                }
                .sheet(isPresented: $showReceipt) {
                    ReceiptView(
                        product: product,
                        amountG: amountG,
                        nutrition: nutrition,
                        mealType: appState.selectedMealType
                    )
                    .environmentObject(appState)
                    .onDisappear {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isFavorite = appState.isFavorite(product)
            HapticFeedbackService.shared.trigger(.barcodeDetected)
        }
    }
    
    private func toggleFavorite() {
        appState.toggleFavorite(product: product)
        isFavorite.toggle()
        HapticFeedbackService.shared.trigger(.favoriteToggle)
    }
}

// MARK: - Supporting Views

struct NutritionRowView: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(label)
                    .font(.body)
            }
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundColor(color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
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
        isVerified: false,
        createdAt: Date()
    )
    
    let appState = AppState()
    
    ProductDetailView(product: mockProduct, appState: appState)
}
