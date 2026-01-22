import SwiftUI

struct ReceiptView: View {
    let product: Product
    let amountG: Double
    let nutrition: NutritionBreakdown
    let mealType: String
    let onAction: (ReceiptAction) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Success Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.brand)
                    
                    Text("Logget!")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.ink)
                    
                    Text(mealType)
                        .font(AppTypography.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(20)
                
                Divider()
                
                // Receipt Content
                VStack(spacing: 16) {
                    // Product Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.ink)
                        Text("\(Int(amountG))g")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Nutrition Summary
                    VStack(spacing: 8) {
                        HStack {
                            Text("Energi")
                            Spacer()
                            Text("\(Int(nutrition.calories)) kcal")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                        }
                        
                        HStack {
                            Text("Protein")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.protein))g")
                        }
                        
                        HStack {
                            Text("Karb.")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.carbs))g")
                        }
                        
                        HStack {
                            Text("Fett")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.fat))g")
                        }
                    }
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                }
                .padding(20)
                
                Divider()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        onAction(.scanNext)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Skann en til")
                        }
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.brand)
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            onAction(.addAgain)
                            dismiss()
                        }) {
                            Text("Legg til igjen")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.brand)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.background)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            onAction(.close)
                            dismiss()
                        }) {
                            Text("Lukk")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.brand)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppColors.background)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .cornerRadius(16)
            .padding(20)
        }
        .onAppear {
            // Auto-close after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    let mockProduct = Product(
        id: UUID(),
        name: "Eksempel Produkt",
        brand: nil,
        category: nil,
        barcodeEan: "123456",
        source: "manual",
        kind: .packaged,
        caloriesPer100g: 200,
        proteinGPer100g: 10,
        carbsGPer100g: 25,
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
    
    let nutrition = mockProduct.calculateNutrition(forGrams: 150)
    
    ReceiptView(
        product: mockProduct,
        amountG: 150,
        nutrition: nutrition,
        mealType: "Lunsj",
        onAction: { _ in }
    )
}
