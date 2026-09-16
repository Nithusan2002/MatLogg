import SwiftUI

struct MatLoggTabBar: View {
    @Binding var selection: AppTab

    private let tabs: [(AppTab, String, String)] = [
        (.home, "Hjem", "house"),
        (.search, "Søk", "magnifyingglass"),
        (.progress, "Tall", "chart.bar"),
        (.profile, "Profil", "person")
    ]

    var body: some View {
        HStack(spacing: 4) {
            tabButton(tabs[0])
            tabButton(tabs[1])
            Button { selection = .add } label: {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(AppColors.brand, in: Circle())
                    .overlay(Circle().stroke(AppColors.surface, lineWidth: 4))
                    .shadow(color: AppColors.deepInk.opacity(0.18), radius: 1, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Legg til mat")
            .offset(y: -13)
            tabButton(tabs[2])
            tabButton(tabs[3])
        }
        .frame(height: 66)
        .padding(.horizontal, 10)
        .background(AppColors.surface)
        .background(alignment: .top) {
            Rectangle()
                .fill(AppColors.separator)
                .frame(height: 1)
        }
    }

    private func tabButton(_ tab: (AppTab, String, String)) -> some View {
        Button { selection = tab.0 } label: {
            VStack(spacing: 4) {
                Image(systemName: selection == tab.0 ? "\(tab.2).fill" : tab.2)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.1).font(.caption2)
            }
            .foregroundColor(selection == tab.0 ? AppColors.brand : AppColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == tab.0 ? .isSelected : [])
    }
}

struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var productViewModel: ProductViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var products: [Product] = []
    @State private var selectedProduct: Product?

    let onSearch: () -> Void
    let onScan: () -> Void
    let onManualAdd: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Loggfør mat")
                        .font(AppTypography.title)
                        .foregroundColor(AppColors.deepInk)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundColor(AppColors.deepInk)
                            .frame(width: 44, height: 44)
                            .background(AppColors.mutedSurface, in: Circle())
                    }
                    .accessibilityLabel("Lukk")
                }

                QuickSearchBar(onSearch: onSearch, onScan: onScan)

                mealPicker

                if products.isEmpty {
                    VStack(spacing: 10) {
                        Text("Ingen hurtigvalg ennå")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.deepInk)
                        Text("Søk etter eller skann en matvare. Nylig brukte og favoritter vises her neste gang.")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Legg til manuelt", action: onManualAdd)
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.brand)
                            .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(products) { product in
                            Button { selectedProduct = product } label: {
                                HStack(spacing: 12) {
                                    Text(String(product.name.prefix(1)).uppercased())
                                        .font(AppTypography.bodyEmphasis)
                                        .foregroundColor(AppColors.deepInk)
                                        .frame(width: 44, height: 44)
                                        .background(AppColors.mutedSurface, in: Circle())
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(product.name)
                                            .font(AppTypography.bodyEmphasis)
                                            .foregroundColor(AppColors.deepInk)
                                            .lineLimit(1)
                                        Text(productSubtitle(product))
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(12)
                                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task { await loadProducts() }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product, appState: appState, onLogComplete: nil)
        }
    }

    private var mealPicker: some View {
        HStack(spacing: 8) {
            ForEach(MealPresentation.all) { meal in
                Button {
                    appState.selectedMealType = meal.key
                } label: {
                    Text(meal.title)
                        .font(AppTypography.captionEmphasis)
                        .foregroundColor(appState.selectedMealType == meal.key ? .white : AppColors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(appState.selectedMealType == meal.key ? AppColors.brand : AppColors.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(appState.selectedMealType == meal.key ? .isSelected : [])
            }
        }
    }

    private func loadProducts() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        let favorites = await productViewModel.favoriteProducts(userId: userId)
        let recents = await productViewModel.recentProducts(userId: userId, limit: 8)
        var seen = Set<UUID>()
        products = (favorites + recents).filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
    }

    private func productSubtitle(_ product: Product) -> String {
        let brand = product.brand.map { "\($0) · " } ?? ""
        return "\(brand)\(product.caloriesPer100g) kcal per 100 g"
    }
}
