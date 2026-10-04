import SwiftUI
import UIKit

struct LogToastView: View {
    private let receiptID: UUID
    private let title: String
    let isUndoing: Bool
    let onUndo: () -> Void
    let onDismiss: () -> Void

    init(payload: ReceiptPayload, isUndoing: Bool, onUndo: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.init(id: payload.id,
                  title: "\(PortionDisplay.amount(payload.amountG, unit: payload.amountUnit, portion: payload.portionSelection)) \(payload.product.name) lagt til \(LogSummaryService.title(for: payload.mealType))",
                  isUndoing: isUndoing, onUndo: onUndo, onDismiss: onDismiss)
    }

    init(id: UUID, title: String, isUndoing: Bool, onUndo: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.receiptID = id
        self.title = title
        self.isUndoing = isUndoing
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(AppColors.success)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
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
                    .foregroundColor(AppColors.actionText)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(isUndoing)
        }
        .padding(14)
        .matLoggCardSurface(cornerRadius: 16)
        .contentShape(Rectangle())
        .offset(y: dragOffset)
        .opacity(1 - min(dragOffset / 180, 0.55))
        .simultaneousGesture(dismissGesture)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Lukk bekreftelse") {
            onDismiss()
        }
        .onChange(of: receiptID) {
            dragOffset = 0
        }
        .task(id: "\(receiptID)-\(isUndoing)") {
            guard !isUndoing else { return }
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
    
}

extension AnyTransition {
    static var logToast: AnyTransition {
        .asymmetric(
            insertion: .offset(y: 24).combined(with: .opacity),
            removal: .offset(y: 42).combined(with: .opacity)
        )
    }
}
