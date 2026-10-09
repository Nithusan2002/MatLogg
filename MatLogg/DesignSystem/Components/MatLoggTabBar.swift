import SwiftUI

struct MatLoggTabBar: View {
    static let defaultScrollContentBottomMargin: CGFloat = 104
    static let scrollContentSpacing: CGFloat = 16

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var selection: AppTab
    var diarySelection: MatLoggDiarySelectionPresentation? = nil

    private let tabs: [(AppTab, String, String)] = [
        (.home, "Hjem", "house"),
        (.search, "Søk", "magnifyingglass"),
        (.progress, "Utvikling", "chart.bar"),
        (.profile, "Profil", "person")
    ]

    var body: some View {
        ZStack {
            if let diarySelection {
                MatLoggSelectionBar(count: diarySelection.count,
                    canSave: diarySelection.canSave, isBusy: diarySelection.isBusy,
                    onSave: diarySelection.onSave, onDelete: diarySelection.onDelete)
                    .transition(.opacity)
            } else {
                tabBarContent.transition(.opacity)
            }
        }
        .modifier(MatLoggBottomBarSurface())
    }

    @ViewBuilder private var tabBarContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView(.horizontal) {
                tabButtons
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("matlogg-tab-bar-scroll")
            .fixedSize(horizontal: false, vertical: true)
        } else {
            tabButtons
        }
    }

    private var tabButtons: some View {
        HStack(spacing: 4) {
            tabButton(tabs[0])
            tabButton(tabs[1])
            Button { selection = .add } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .semibold))
                        .foregroundColor(AppColors.onVibrant)
                        .frame(width: 56, height: 56)
                        .background {
                            Circle().fill(AppColors.brand)
                                .shadow(color: AppColors.deepInk.opacity(0.10), radius: 6, y: 2)
                        }
                        .overlay(Circle().stroke(AppColors.surface, lineWidth: 2))
                    Text("Loggfør")
                        .font(AppTypography.captionEmphasis)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: dynamicTypeSize.isAccessibilitySize, vertical: true)
                        .foregroundColor(AppColors.deepInk)
                }
                .frame(maxWidth: .infinity, minHeight: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Loggfør mat")
            .accessibilityIdentifier("tab-log-food")
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
                    .fixedSize(horizontal: dynamicTypeSize.isAccessibilitySize, vertical: true)
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

/// Tab content can yield its navigation space while an input is being edited.
struct MatLoggTabBarEditingKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

/// Shares the existing bottom navigation surface with contextual selection actions.
private struct MatLoggBottomBarSurface: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .offset(y: 14)
        } else {
            content
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
}

struct MatLoggSelectionBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let count: Int
    let canSave: Bool
    let isBusy: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if count > 50 {
                Text("Velg opptil 50 matvarer for å lagre som måltid.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if dynamicTypeSize.isAccessibilitySize {
                selectionCount.padding(.horizontal, 8)
                HStack(spacing: 8) { actionButtons }
            } else {
                HStack(spacing: 8) {
                    selectionCount.frame(maxWidth: .infinity)
                    Divider().frame(height: 32)
                    actionButtons
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("meal-room-selection-bar")
    }

    private var selectionCount: some View {
        Text("\(count) valgt")
            .font(AppTypography.bodyEmphasis)
            .foregroundStyle(AppColors.ink)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(reduceMotion ? .identity : .numericText())
            .accessibilityIdentifier("meal-room-selection-count")
    }

    @ViewBuilder private var actionButtons: some View {
        Button(action: onSave) {
            actionLabel("Lagre måltid", systemImage: "square.stack.3d.up")
        }
        .buttonStyle(.plain)
        .disabled(!canSave || isBusy)
        .opacity(canSave && !isBusy ? 1 : 0.4)
        .accessibilityLabel("Lagre som måltid")
        .accessibilityIdentifier("meal-room-save-selection")
        Divider().frame(height: 32).accessibilityHidden(true)
        Button(role: .destructive, action: onDelete) {
            actionLabel("Slett", systemImage: "trash")
        }
        .buttonStyle(.plain)
        .disabled(count == 0 || isBusy)
        .opacity(count > 0 && !isBusy ? 1 : 0.4)
        .accessibilityLabel("Slett valgte registreringer")
        .accessibilityIdentifier("meal-room-delete-selection")
    }

    private func actionLabel(_ title: String, systemImage: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage).font(.system(size: 20, weight: .medium))
            Text(title).font(AppTypography.captionEmphasis)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppColors.action)
        .frame(maxWidth: .infinity, minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// UI projection only; diary state and actions remain owned by the feature.
struct MatLoggDiarySelectionPresentation: Equatable {
    let contextID: ObjectIdentifier
    let count: Int
    let canSave: Bool
    let isBusy: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.contextID == rhs.contextID && lhs.count == rhs.count &&
        lhs.canSave == rhs.canSave && lhs.isBusy == rhs.isBusy
    }
}

struct MatLoggDiarySelectionKey: PreferenceKey {
    static let defaultValue: MatLoggDiarySelectionPresentation? = nil
    static func reduce(value: inout MatLoggDiarySelectionPresentation?,
                       nextValue: () -> MatLoggDiarySelectionPresentation?) {
        if let next = nextValue() { value = next }
    }
}
