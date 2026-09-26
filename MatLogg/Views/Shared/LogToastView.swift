import SwiftUI
import UIKit

struct LogToastView: View {
    let payload: ReceiptPayload
    let isUndoing: Bool
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(AppColors.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(formatAmount(payload.amountG)) \(payload.amountUnit.rawValue) \(payload.product.name) lagt til \(mealTitle)")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Lagret på enheten")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer(minLength: 0)

            Button(action: onUndo) {
                Text(isUndoing ? "Angrer …" : "Angre")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.action)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isUndoing)
        }
        .padding(14)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        .contentShape(Rectangle())
        .offset(y: dragOffset)
        .opacity(1 - min(dragOffset / 180, 0.55))
        .simultaneousGesture(dismissGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Lukk bekreftelse") {
            onDismiss()
        }
        .onChange(of: payload.id) {
            dragOffset = 0
        }
        .task(id: payload.id) {
            try? await Task.sleep(for: .seconds(UIAccessibility.isVoiceOverRunning ? 8 : 4))
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isUndoing else { return }
                let isPrimarilyDownward = value.translation.height > abs(value.translation.width)
                dragOffset = isPrimarilyDownward ? max(0, value.translation.height) : 0
            }
            .onEnded { value in
                guard !isUndoing else {
                    resetDragOffset()
                    return
                }

                let shouldDismiss = value.translation.height > 52
                    || value.predictedEndTranslation.height > 120

                if shouldDismiss {
                    onDismiss()
                } else {
                    resetDragOffset()
                }
            }
    }

    private func resetDragOffset() {
        if UIAccessibility.isReduceMotionEnabled {
            dragOffset = 0
        } else {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                dragOffset = 0
            }
        }
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

extension AnyTransition {
    static var logToast: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 24).combined(with: .opacity),
            removal: .offset(y: 42).combined(with: .opacity)
        )
    }
}
