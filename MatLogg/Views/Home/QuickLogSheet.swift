import SwiftUI

struct QuickLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var viewModel: QuickLogViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var logViewModel: LogViewModel
    @EnvironmentObject private var savedMealsViewModel: SavedMealsViewModel
    @State private var selectedSavedMeal: SavedMeal?
    @State private var showAllSavedMeals = false
    @State private var selectedReuseList = ReuseList.recent
    @State private var hasSelectedReuseList = false
    @State private var initialSelectionResolved = false
    @State private var loadID = UUID()

    private enum ReuseList: String, CaseIterable {
        case recent = "Nylig logget"
        case saved = "Lagrede måltider"
    }

    let onSearch: () -> Void
    let onScan: () -> Void
    let onManualAdd: () -> Void
    let onLogComplete: (ReceiptPayload) -> Void
    let onSavedMealLogComplete: () -> Void
    var productSelectionContent: ((Product) -> AnyView)? = nil

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(productSelectionContent == nil ? "Loggfør mat" : "Legg til i måltidet")
                            .font(AppTypography.title)
                            .foregroundColor(AppColors.deepInk)
                        Spacer()
                        ActivityIndicatorSlot(isActive: (viewModel.showsLoadingFeedback && !viewModel.recentFoods.isEmpty)
                                              || (savedMealsViewModel.showsLoadingFeedback && !savedMealsViewModel.meals.isEmpty),
                                              label: "Oppdaterer hurtigvalg og måltider")
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
                    .foregroundStyle(AppColors.actionText)
                    .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("quick-log-manual")

                    if productSelectionContent == nil {
                        mealPicker
                        reuseListPicker
                        if selectedReuseList == .recent { recentContent }
                        else { savedContent }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
                .frame(width: geometry.size.width, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: [.horizontal, .vertical])
            .accessibilityIdentifier("quick-log-scroll")
        }
        .background(AppColors.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            if let payload = viewModel.repeatReceipt {
                LogToastView(payload: payload, isUndoing: viewModel.isUndoingRepeat,
                    onUndo: { undoRepeat(payload) },
                    onDismiss: { viewModel.dismissRepeatReceipt() })
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .task(id: authViewModel.currentUser?.id) {
            if productSelectionContent == nil { await loadContent() }
            else { await viewModel.load(userId: authViewModel.currentUser?.id) }
        }
        .onChange(of: appState.logSelectedDate) { _, _ in viewModel.invalidateRepeatPresentation() }
        .onChange(of: appState.selectedMealType) { _, _ in viewModel.invalidateRepeatPresentation() }
        .onChange(of: authViewModel.currentUser?.id) { _, _ in
            viewModel.invalidateRepeatPresentation()
            selectedReuseList = .recent
            hasSelectedReuseList = false
            initialSelectionResolved = false
            selectedSavedMeal = nil
            showAllSavedMeals = false
        }
        .onDisappear { viewModel.invalidateRepeatPresentation() }
        .sheet(item: $viewModel.selectedQuickProduct) { product in
            if let productSelectionContent {
                productSelectionContent(product)
            } else {
            ProductDetailView(product: product, appState: appState) { payload in
                dismiss()
                onLogComplete(payload)
            }
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

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = viewModel.logError {
                ErrorMessageView(error).font(AppTypography.caption)
            }
            ForEach(viewModel.recentFoods) { food in
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        guard !viewModel.isRepeating else { return }
                        viewModel.selectedQuickProduct = food.product
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(food.product.name)
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.deepInk)
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(AppColors.textSecondary)
                            }
                            if !food.canRepeat {
                                Text("Sist logget: \(food.amountLabel)")
                                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Åpner mengdevalg og loggføring")
                    Button {
                        guard !viewModel.isRepeating else { return }
                        if food.canRepeat { repeatFood(food) }
                        else { viewModel.selectedQuickProduct = food.product }
                    } label: {
                        HStack(spacing: 8) {
                            ZStack(alignment: .leading) {
                                Text(viewModel.confirmedProductID == food.id ? "Lagt til ✓" :
                                    (food.canRepeat ? "Loggfør \(food.amountLabel)" : "Kontroller mengde"))
                                    .opacity(viewModel.showsRepeatFeedback && viewModel.repeatingProductID == food.id ? 0 : 1)
                                Text("Lagrer …").hidden()
                                if viewModel.showsRepeatFeedback && viewModel.repeatingProductID == food.id {
                                    Text("Lagrer …")
                                }
                            }
                            ActivityIndicatorSlot(isActive: viewModel.showsRepeatFeedback && viewModel.repeatingProductID == food.id,
                                                  label: "Lagrer på enheten")
                        }
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.actionText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppColors.chipFillSelected, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.chipStroke, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(food.canRepeat
                        ? "Loggfør \(food.product.name), \(food.amountLabel)"
                        : "Kontroller mengde for \(food.product.name)")
                    .accessibilityValue(viewModel.showsRepeatFeedback && viewModel.repeatingProductID == food.id ? "Lagrer på enheten" : "")
                    .accessibilityHint("Til \(selectedMealTitle), \(logDateLabel)")
                    .accessibilityIdentifier("quick-log-repeat-\(food.id.uuidString)")
                }
                .padding(12)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
                .allowsHitTesting(!viewModel.isRepeating && !viewModel.isUndoingRepeat)
            }
        }
    }

    private func repeatFood(_ food: RecentFood) {
        let date = appState.logSelectedDate
        let meal = appState.selectedMealType
        let owner = authViewModel.currentUser?.id
        Task {
            guard await viewModel.logAgain(food, mealType: meal, date: date) != nil,
                  authViewModel.currentUser?.id == owner,
                  appState.logSelectedDate == date, appState.selectedMealType == meal else { return }
            logViewModel.didPersistExternalLog()
            UIAccessibility.post(notification: .announcement, argument: "\(food.product.name) lagt til")
            await appState.refreshSyncStatus()
        }
    }

    private func undoRepeat(_ payload: ReceiptPayload) {
        guard let owner = authViewModel.currentUser?.id,
              payload.ownerID == owner, viewModel.beginRepeatUndo() else { return }
        Task {
            let succeeded = await logViewModel.undoLatestLog(productId: payload.product.id,
                mealType: payload.mealType, amountG: Float(payload.amountG), userId: owner,
                date: payload.loggedDate, logID: payload.logID)
            if succeeded, viewModel.repeatReceipt?.id == payload.id {
                viewModel.dismissRepeatReceipt()
            } else if !succeeded, authViewModel.currentUser?.id == owner {
                viewModel.showRepeatUndoError()
            }
            viewModel.finishRepeatUndo()
            await appState.refreshSyncStatus()
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
                    .foregroundStyle(AppColors.actionText)
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

    private var reuseListPicker: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            ForEach(ReuseList.allCases, id: \.self) { list in
                MealChip(title: list.rawValue, isSelected: selectedReuseList == list, fillsWidth: true) {
                    hasSelectedReuseList = true
                    selectedReuseList = list
                }
                .accessibilityIdentifier(list == .recent ? "quick-log-show-recent" : "quick-log-show-saved")
            }
        }
        .accessibilityLabel("Velg gjenbruk")
    }

    @ViewBuilder private var recentContent: some View {
        if let error = viewModel.errorMessage {
            ErrorMessageView(error).font(AppTypography.caption)
            Button("Prøv igjen") { Task { await loadContent() } }.frame(minHeight: 44)
        }
        if !viewModel.recentFoods.isEmpty {
            repeatSection
        } else if viewModel.isLoading || !viewModel.hasLoaded {
            ProgressView("Henter nylig loggede matvarer …")
        } else if viewModel.errorMessage == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ingen nylig loggede matvarer")
                    .font(AppTypography.bodyEmphasis)
                Text("Matvarer du logger, vises her.")
                    .font(AppTypography.secondary).foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    @ViewBuilder private var savedContent: some View {
        if let error = savedMealsViewModel.loadError {
            ErrorMessageView(error).font(AppTypography.caption)
            Button("Prøv igjen") { Task { await loadContent() } }.frame(minHeight: 44)
        }
        if savedMealsViewModel.isLoading && savedMealsViewModel.meals.isEmpty {
            ProgressView("Henter lagrede måltider …")
        } else if !savedMealsViewModel.meals.isEmpty || savedMealsViewModel.loadError == nil {
            savedMealsSection
        }
    }

    private var mealPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Måltid")
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
                        Text(appState.selectedMealType == meal.key ? "\(meal.title) ✓" : meal.title)
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
        let userId = authViewModel.currentUser?.id
        let request = UUID()
        loadID = request
        async let quick: Void = viewModel.load(userId: userId)
        async let meals: Void = savedMealsViewModel.load(userId: userId)
        _ = await (quick, meals)
        guard !Task.isCancelled, loadID == request,
              authViewModel.currentUser?.id == userId,
              !initialSelectionResolved,
              viewModel.errorMessage == nil, savedMealsViewModel.loadError == nil else { return }
        initialSelectionResolved = true
        if !hasSelectedReuseList && viewModel.recentFoods.isEmpty && !savedMealsViewModel.meals.isEmpty {
            selectedReuseList = .saved
        }
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
    var productSelectionContent: ((Product) -> AnyView)? = nil

    var body: some View {
        QuickLogSheet(
            onSearch: { destination = .search },
            onScan: { destination = .scan },
            onManualAdd: { destination = .manual },
            onLogComplete: complete,
            onSavedMealLogComplete: {
                dismiss()
                onSavedMealLogComplete()
            },
            productSelectionContent: productSelectionContent
        )
        .fullScreenCover(item: $destination, onDismiss: viewModel.finishManualCreation) { route in
            switch route {
            case .search:
                if productSelectionContent == nil {
                    RawMaterialsSearchView(onLogComplete: complete)
                } else {
                NavigationStack {
                    FoodSearchView(focusOnAppear: true, onScan: { destination = .scan },
                        onLogComplete: complete, productSelectionContent: productSelectionContent)
                        .navigationTitle("Søk")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Avbryt") { destination = nil }
                            }
                        }
                }
                }
            case .manual:
                ManualProductView(barcode: nil, saveProduct: viewModel.saveManual, onSaved: viewModel.manualProductSaved)
            case .scan:
                CameraView(onLogComplete: complete, onSearch: { destination = .search },
                           productSelectionContent: productSelectionContent)
            }
        }
        .sheet(item: $viewModel.selectedManualProduct) { product in
            if let productSelectionContent { productSelectionContent(product) }
            else { ProductDetailView(product: product, appState: appState, onLogComplete: complete) }
        }
    }

    private func complete(_ payload: ReceiptPayload) {
        dismiss()
        onLogComplete(payload)
    }
}
