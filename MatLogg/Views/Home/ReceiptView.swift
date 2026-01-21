import SwiftUI

struct ReceiptView: View {
    let product: Product
    let amountG: Double
    let nutrition: NutritionBreakdown
    let mealType: String
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var autoClosing = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Success Header
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    
                    Text("Logget!")
                        .font(.headline)
                    
                    Text(mealType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                
                Divider()
                
                // Receipt Content
                VStack(spacing: 16) {
                    // Product Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        Text("\(Int(amountG))g")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Divider()
                    
                    // Nutrition Summary
                    VStack(spacing: 8) {
                        HStack {
                            Text("Energi")
                            Spacer()
                            Text("\(Int(nutrition.calories)) kcal")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Protein")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.proteinG))g")
                        }
                        
                        HStack {
                            Text("Karb.")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.carbsG))g")
                        }
                        
                        HStack {
                            Text("Fett")
                            Spacer()
                            Text("\(String(format: "%.1f", nutrition.fatG))g")
                        }
                    }
                    .font(.subheadline)
                }
                .padding(20)
                
                Divider()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Skann ein til")
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: { dismiss() }) {
                            Text("Legg til igjen")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            appState.selectedTab = 0
                            dismiss()
                        }) {
                            Text("Lukk")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
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
        barcode: "123456",
        name: "Eksempel Produkt",
        caloriesPer100g: 200,
        proteinG: 10,
        carbsG: 25,
        fatG: 8,
        source: .manual,
        createdAt: Date()
    )
    
    let nutrition = mockProduct.calculateNutrition(forGrams: 150)
    
    return ReceiptView(
        product: mockProduct,
        amountG: 150,
        nutrition: nutrition,
        mealType: "Lunsj"
    )
    .environmentObject(AppState())
}
