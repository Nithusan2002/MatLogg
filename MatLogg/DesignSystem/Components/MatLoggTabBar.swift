import SwiftUI

struct MatLoggTabBar: View {
    static let defaultScrollContentBottomMargin: CGFloat = 104
    static let scrollContentSpacing: CGFloat = 16

    @Binding var selection: AppTab

    private let tabs: [(AppTab, String, String)] = [
        (.home, "Hjem", "house"),
        (.search, "Søk", "magnifyingglass"),
        (.progress, "Oversikt", "chart.bar"),
        (.profile, "Profil", "person")
    ]

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            tabBarContent
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .offset(y: 8)
        } else {
            tabBarContent
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(AppColors.surface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AppColors.separator)
                        .frame(height: 1)
                }
        }
    }

    private var tabBarContent: some View {
        HStack(spacing: 4) {
            tabButton(tabs[0])
            tabButton(tabs[1])
            Button { selection = .add } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(AppColors.onVibrant)
                        .frame(width: 56, height: 56)
                        .background(AppColors.brand, in: Circle())
                        .overlay(Circle().stroke(AppColors.surface, lineWidth: 2))
                        .shadow(color: AppColors.deepInk.opacity(0.10), radius: 6, y: 2)
                    Text("Loggfør")
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(AppColors.deepInk)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Loggfør mat")
            .padding(.top, -4)
            tabButton(tabs[2])
            tabButton(tabs[3])
        }
        .frame(minHeight: 70)
    }

    private func tabButton(_ tab: (AppTab, String, String)) -> some View {
        Button { selection = tab.0 } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == tab.0 && tab.0 != .search ? "\(tab.2).fill" : tab.2)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.1)
                    .font(selection == tab.0 ? AppTypography.captionEmphasis : AppTypography.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(selection == tab.0 ? AppColors.action : AppColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab.0 ? .isSelected : [])
    }
}

private struct MatLoggTabBarScrollMarginKey: EnvironmentKey {
    static let defaultValue = MatLoggTabBar.defaultScrollContentBottomMargin
}

extension EnvironmentValues {
    var matLoggTabBarScrollMargin: CGFloat {
        get { self[MatLoggTabBarScrollMarginKey.self] }
        set { self[MatLoggTabBarScrollMarginKey.self] = newValue }
    }
}

private struct MatLoggTabBarScrollClearanceModifier: ViewModifier {
    @Environment(\.matLoggTabBarScrollMargin) private var bottomMargin

    func body(content: Content) -> some View {
        content.contentMargins(.bottom, bottomMargin, for: .scrollContent)
    }
}

extension View {
    /// Keeps the final content in a tab-hosted scroll container above MatLogg's custom tab bar.
    func matLoggTabBarScrollClearance() -> some View {
        modifier(MatLoggTabBarScrollClearanceModifier())
    }
}
