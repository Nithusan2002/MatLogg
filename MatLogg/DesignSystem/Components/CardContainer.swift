import SwiftUI

struct CardContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .matLoggCardSurface()
    }
}

private struct MatLoggCardSurface<Fill: ShapeStyle>: ViewModifier {
    let fill: Fill
    let cornerRadius: CGFloat
    let shadowEnabled: Bool
    let borderEnabled: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .clipShape(shape)
            .background {
                // Shadow only the surface, never text or controls in the card.
                shape.fill(fill)
                    .shadow(color: shadowEnabled ? AppColors.deepInk.opacity(0.06) : .clear,
                            radius: 12, x: 0, y: 4)
            }
            .overlay {
                if borderEnabled {
                    shape.stroke(AppColors.separator.opacity(0.6), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func matLoggCardSurface<Fill: ShapeStyle>(
        fill: Fill = AppColors.surface,
        cornerRadius: CGFloat = 18,
        shadowEnabled: Bool = true,
        borderEnabled: Bool = true
    ) -> some View {
        modifier(MatLoggCardSurface(fill: fill, cornerRadius: cornerRadius,
                                   shadowEnabled: shadowEnabled, borderEnabled: borderEnabled))
    }
}
