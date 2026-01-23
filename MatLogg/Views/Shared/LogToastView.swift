import SwiftUI

struct LogToastView: View {
    let payload: ReceiptPayload
    let onUndo: () -> Void
    let onScanNext: () -> Void
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("✅ Logget til \(mealTitle)")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.ink)
                Spacer()
            }
            
            HStack(spacing: 8) {
                Text("\(payload.product.name) · \(formatAmount(payload.amountG)) g")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: onUndo) {
                    Text("Angre")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(AppColors.brand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.separator, lineWidth: 1)
                        )
                        .cornerRadius(12)
                }
                
                Button(action: onScanNext) {
                    Text("Skann en til")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.brand)
                        .cornerRadius(12)
                }
            }
        }
        .padding(14)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .offset(y: dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if value.translation.height > 50 {
                        onDismiss()
                    }
                    dragOffset = .zero
                }
        )
    }
    
    private var mealTitle: String {
        LogSummaryService.title(for: payload.mealType)
    }
    
    private func formatAmount(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }
}
