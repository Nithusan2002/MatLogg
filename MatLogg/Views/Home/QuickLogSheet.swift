import SwiftUI

struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: QuickLogViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel
    @State private var selectedProduct: Product?
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

                Button(action: onManualAdd) {
                    Label("Registrer manuelt", systemImage: "square.and.pencil")
                        .font(AppTypography.bodyEmphasis)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .foregroundStyle(AppColors.action)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("quick-log-manual")

                mealPicker

                savedMealsSection

                if viewModel.isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Henter hurtigvalg …")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .accessibilityElement(children: .combine)
                } else if viewModel.errorMessage != nil {
                    VStack(spacing: 10) {
                        Label("Kunne ikke hente hurtigvalg", systemImage: "exclamationmark.triangle")
                            .font(AppTypography.bodyEmphasis)
                        Button("Prøv igjen") { Task { await loadContent() } }
                            .font(AppTypography.bodyEmphasis)
                            .foregroundColor(AppColors.action)
                            .frame(minHeight: 44)
                    }
                    .frame(maxWidth: .infinity, minHeight: 120)
                } else if viewModel.products.isEmpty {
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
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        quickProductsHeading
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.products) { product in
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
        .task(id: authViewModel.currentUser?.id) { await loadContent() }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Lagrede måltider")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.deepInk)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(savedMealsViewModel.meals.isEmpty ? "Åpne" : "Se alle") { showAllSavedMeals = true }
                    .accessibilityIdentifier("quick-log-saved-meals")
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.action)
                    .frame(minHeight: 44)
            }
            if savedMealsViewModel.meals.isEmpty {
                Text("Lagre et registrert måltid fra Gjenbruk-menyen i dagsloggen.")
                    .font(AppTypography.secondary)
                    .foregroundStyle(AppColors.textSecondary)
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
                .font(AppTypography.secondary)
                .foregroundColor(AppColors.textSecondary)

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
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
        await viewModel.load(userId: authViewModel.currentUser?.id)
        if let userId = authViewModel.currentUser?.id {
            await savedMealsViewModel.load(userId: userId)
        }
    }

    private func productSubtitle(_ product: Product) -> String {
        let brand = product.brand.map { "\($0) · " } ?? ""
        return "\(brand)\(NutritionDisplay.wholeCalories(product.caloriesPer100g)) kcal per 100 \(product.amountUnit.rawValue)"
    }
}

/// Every entry point keeps the same date and meal context throughout logging.
struct LoggingFlowView: View {
    private enum Destination: String, Identifiable {
        case search, scan, manual
        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: QuickLogViewModel
    @EnvironmentObject private var appState: AppState
    @State private var destination: Destination?
    let onLogComplete: (ReceiptPayload) -> Void
    let onSavedMealLogComplete: () -> Void

    var body: some View {
        QuickLogSheet(
            onSearch: { destination = .search },
            onScan: { destination = .scan },
            onManualAdd: { destination = .manual },
            onLogComplete: complete,
            onSavedMealLogComplete: {
                dismiss()
                onSavedMealLogComplete()
            }
        )
        .fullScreenCover(item: $destination, onDismiss: viewModel.finishManualCreation) { route in
            switch route {
            case .search:
                RawMaterialsSearchView(onLogComplete: complete)
            case .manual:
                ManualProductView(barcode: nil, saveProduct: viewModel.saveManual, onSaved: viewModel.manualProductSaved)
            case .scan:
                CameraView(onLogComplete: complete, onSearch: { destination = .search })
            }
        }
        .sheet(item: $viewModel.selectedManualProduct) { product in
            ProductDetailView(product: product, appState: appState, onLogComplete: complete)
        }
    }

    private func complete(_ payload: ReceiptPayload) {
        dismiss()
        onLogComplete(payload)
    }
}
