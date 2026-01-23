import SwiftUI

struct ThemePreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Theme Preview")
                    .font(AppTypography.title)
                    .foregroundColor(AppColors.ink)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Colors")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    
                    colorRow(name: "Background", color: AppColors.background)
                    colorRow(name: "Surface", color: AppColors.surface)
                    colorRow(name: "Ink", color: AppColors.ink)
                    colorRow(name: "Text Secondary", color: AppColors.textSecondary)
                    colorRow(name: "Separator", color: AppColors.separator)
                    colorRow(name: "Brand", color: AppColors.brand)
                    colorRow(name: "Accent", color: AppColors.accent)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Components")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.ink)
                    
                    CardContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Card Container")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.ink)
                            
                            ProgressRow(
                                label: "Proteiner",
                                valueText: "45g / 120g",
                            progress: 0.38, tint: AppColors.brand
                            )
                        }
                    }
                    
                    PrimaryButton(title: "Skann", systemImage: "barcode.viewfinder") {}
                    
                    HStack(spacing: 12) {
                        MealChip(title: "Frokost", isSelected: false, action: {})
                        MealChip(title: "Lunsj", isSelected: true, action: {})
                    }
                }
            }
            .padding(16)
        }
        .background(AppColors.background.ignoresSafeArea())
        .navigationTitle("Theme")
    }
    
    private func colorRow(name: String, color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 48, height: 32)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.separator, lineWidth: 1)
                )
            Text(name)
                .font(AppTypography.body)
                .foregroundColor(AppColors.ink)
        }
    }
}
