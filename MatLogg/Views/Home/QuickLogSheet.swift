import SwiftUI

struct QuickLogSheet: View {
    private enum LoadState: Equatable {
        case loading
        case content
        case empty
        case unavailable
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var productViewModel: ProductViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel
    @State private var products: [Product] = []
    @State private var selectedProduct: Product?
    @State private var loadState: LoadState = .loading
    @State private var selectedSavedMeal: SavedMeal?
    @State private var showAllSavedMeals = false

    let onSearch: () -> Void
    let onScan: () -> Void
    let onManualAdd: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    let onSavedMealLogComplete: () -> Void

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

                savedMealsSection

                if loadState == .loading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Henter hurtigvalg …")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityElement(children: .combine)
                } else if loadState == .unavailable {
                    VStack(spacing: 10) {
                        Label("Kunne ikke hente hurtigvalg", systemImage: "exclamationmark.triangle")
                            .font(AppTypography.bodyEmphasis)
                        Button("Prøv igjen") { Task { await loadContent() } }
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.action)
                            .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if loadState == .empty {
                    VStack(alignment: .leading, spacing: 10) {
                        quickProductsHeading
                        VStack(spacing: 10) {
                            Text("Ingen enkeltvarer i hurtigvalg ennå")
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.deepInk)
                            Text("Søk etter eller skann en matvare. Nylig brukte enkeltvarer og favoritter vises her neste gang.")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                            Button("Legg til manuelt", action: onManualAdd)
                                .font(AppTypography.bodyEmphasis)
                                .foregroundColor(AppColors.action)
                                .frame(minHeight: 44)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        quickProductsHeading
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
                                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(AppColors.background.ignoresSafeArea())
        .task { await loadContent() }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product, appState: appState) { payload in
                dismiss()
                onLogComplete(payload)
            }
        }
        .sheet(item: $selectedSavedMeal) { meal in
            SavedMealLogView(meal: meal) {
                selectedSavedMeal = nil
                dismiss()
                onSavedMealLogComplete()
            }
        }
        .sheet(isPresented: $showAllSavedMeals) {
            SavedMealsListView {
                showAllSavedMeals = false
                dismiss()
                onSavedMealLogComplete()
            }
        }
    }

    @ViewBuilder private var savedMealsSection: some View {
        if !savedMealsViewModel.meals.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Lagrede måltider")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.deepInk)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button("Se alle") { showAllSavedMeals = true }
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.action)
                        .frame(minHeight: 44)
                }
                ForEach(savedMealsViewModel.meals.prefix(3)) { meal in
                    Button { selectedSavedMeal = meal } label: {
                        SavedMealRow(meal: meal)
                            .padding(12)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AppColors.separator.opacity(0.6), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quickProductsHeading: some View {
        Text("Favoritter og nylig brukt")
            .font(AppTypography.sectionTitle)
            .foregroundStyle(AppColors.deepInk)
            .accessibilityAddTraits(.isHeader)
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Logg til: \(selectedMealTitle)")
                .font(AppTypography.bodyEmphasis)
                .foregroundColor(AppColors.deepInk)

            Label(logDateLabel, systemImage: "calendar")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(MealPresentation.all) { meal in
                    Button {
                        appState.selectedMealType = meal.key
                    } label: {
                        Text(meal.title)
                            .font(AppTypography.captionEmphasis)
                            .foregroundColor(appState.selectedMealType == meal.key ? AppColors.onVibrant : AppColors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(appState.selectedMealType == meal.key ? AppColors.brand : AppColors.surface, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Logg til \(meal.title)")
                    .accessibilityAddTraits(appState.selectedMealType == meal.key ? .isSelected : [])
                }
            }
        }
    }

    private var selectedMealTitle: String {
        MealPresentation.all.first(where: { $0.key == appState.selectedMealType })?.title ?? "måltid"
    }

    private var logDateLabel: String {
        let date = appState.logSelectedDate
        if Calendar.current.isDateInToday(date) { return "I dag" }
        if Calendar.current.isDateInYesterday(date) { return "I går" }
        if Calendar.current.isDateInTomorrow(date) { return "I morgen" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(Locale(identifier: "nb_NO")))
            .capitalized
    }

    private func loadContent() async {
        loadState = .loading
        guard let userId = authViewModel.currentUser?.id else {
            loadState = .unavailable
            return
        }
        await savedMealsViewModel.load(userId: userId)
        let favorites = await productViewModel.favoriteProducts(userId: userId)
        let recents = await productViewModel.recentProducts(userId: userId, limit: 8)
        var seen = Set<UUID>()
        products = (favorites + recents).filter { seen.insert($0.id).inserted }.prefix(8).map { $0 }
        loadState = products.isEmpty ? .empty : .content
    }

    private func productSubtitle(_ product: Product) -> String {
        let brand = product.brand.map { "\($0) · " } ?? ""
        return "\(brand)\(product.caloriesPer100g) kcal per 100 \(product.amountUnit.rawValue)"
    }
}
