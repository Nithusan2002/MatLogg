import SwiftUI

struct ProfileFavoritesView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: ProfileFavoritesViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var selectedProduct: Product?
    @Environment(\.matLoggTabBarScrollMargin) private var bottomMargin

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Henter favoritter …")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("favorites-loading")
            } else if viewModel.products.isEmpty {
                ContentUnavailableView {
                    Label("Ingen favoritter ennå", systemImage: "heart")
                } description: {
                    Text("Trykk på hjertet på en matvare for å finne den raskt igjen her.")
                } actions: {
                    Button("Finn matvarer") {
                        appState.selectedTab = .search
                    }
                    .foregroundColor(AppColors.action)
                }
                .safeAreaPadding(.bottom, bottomMargin)
                .accessibilityIdentifier("favorites-empty-state")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.products) { product in
                            Button {
                                selectedProduct = product
                            } label: {
                                favoriteRow(product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
                .matLoggTabBarScrollClearance()
                .refreshable { await loadFavorites() }
                .accessibilityIdentifier("favorites-list")
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle("Favoritter")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authViewModel.currentUser?.id) { await loadFavorites() }
        .sheet(item: $selectedProduct, onDismiss: {
            Task { await loadFavorites() }
        }) { product in
            ProductDetailView(product: product, appState: appState) { _ in }
        }
    }

    private func favoriteRow(_ product: Product) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.fill")
                .font(.title3)
                .foregroundColor(AppColors.brand)
                .frame(width: 48, height: 48)
                .background(AppColors.brand.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(AppTypography.bodyEmphasis)
                    .foregroundColor(AppColors.deepInk)
                    .multilineTextAlignment(.leading)
                if let brand = product.brand, !brand.isEmpty {
                    Text(brand)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Åpner produktet")
    }

    private func loadFavorites() async {
        await viewModel.load(userId: authViewModel.currentUser?.id)
    }
}
