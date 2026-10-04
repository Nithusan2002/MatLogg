import SwiftUI
import PhotosUI
import UIKit

struct SavedMealCreationSource: Identifiable {
    let id = UUID()
    let mealType: String
    let logs: [FoodLog]
}

struct SaveMealFromLogsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var productViewModel: ProductViewModel
    let source: SavedMealCreationSource
    @State private var name = ""
    private var productNames: [UUID: String] { viewModel.sourceProductNames }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MatLoggSheetHeader(title: "Lagre som måltid", isCloseDisabled: viewModel.isSaving) { dismiss() }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Navn")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppColors.deepInk)
                            CardContainer {
                                TextField("For eksempel Vanlig frokost", text: $name)
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppColors.ink)
                                    .textInputAutocapitalization(.sentences)
                                    .frame(minHeight: 44)
                                    .accessibilityLabel("Navn på måltidet")
                                    .accessibilityIdentifier("saved-meal-name")
                            }
                        }

                        SavedMealPhotoPicker()
                            .disabled(viewModel.isSaving)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Innhold")
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppColors.deepInk)
                            CardContainer {
                                VStack(spacing: 12) {
                                    if viewModel.isLoadingSource { ProgressView("Henter matvarer …") }
                                    ForEach(source.logs) { log in
                                        if log.id != source.logs.first?.id {
                                            Divider().overlay(AppColors.separator)
                                        }
                                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                                            Text(productName(for: log))
                                                .font(AppTypography.bodyEmphasis)
                                                .foregroundStyle(AppColors.deepInk)
                                            Spacer(minLength: 8)
                                            Text(PortionDisplay.amount(Double(log.amountG), unit: log.resolvedAmountUnit, portion: log.portionSelection))
                                                .font(AppTypography.body)
                                                .foregroundStyle(AppColors.textSecondary)
                                                .fixedSize(horizontal: true, vertical: false)
                                        }
                                        .accessibilityElement(children: .combine)
                                    }
                                }
                            }
                            Text("Mengder og næringstall lagres slik de er nå. Tidligere registreringer endres ikke.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .padding(16)
                }
                .disabled(viewModel.isSaving)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let error = viewModel.errorMessage {
                        ErrorMessageView(error)
                            .font(AppTypography.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Lagre") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving || viewModel.isLoadingPhoto || viewModel.isLoadingSource)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving ? 0.5 : 1)
                    .accessibilityIdentifier("saved-meal-save")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.background)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(viewModel.isSaving)
            .onAppear { viewModel.beginPhotoEditing() }
            .onDisappear { viewModel.beginPhotoEditing() }
            .task(id: authViewModel.currentUser?.id) {
                await viewModel.loadCreationSource(logs: source.logs, userId: authViewModel.currentUser?.id)
            }
        }
        .tint(AppColors.action)
        .presentationDragIndicator(.visible)
    }

    private func save() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        if await viewModel.saveFromLogs(
            name: name,
            mealType: source.mealType,
            logs: source.logs,
            userId: userId
        ) {
            dismiss()
        }
    }

    private func productName(for log: FoodLog) -> String {
        productNames[log.productId] ?? "Ukjent matvare"
    }

    private func format(_ amount: Float) -> String {
        amount.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "nb_NO")))
    }
}

struct SavedMealsListView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var selectedMeal: SavedMeal?
    @State private var editingMeal: SavedMeal?
    @State private var deleteCandidate: SavedMeal?
    let onLogged: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.meals.isEmpty {
                    ProgressView("Henter lagrede måltider …")
                } else if let error = viewModel.loadError, viewModel.meals.isEmpty {
                    ContentUnavailableView {
                        Label("Kunne ikke hente måltider", systemImage: "exclamationmark.triangle")
                    } description: {
                        ErrorMessageView(error)
                    } actions: {
                        Button("Prøv igjen") { Task { await viewModel.load(userId: authViewModel.currentUser?.id) } }
                    }
                } else if viewModel.meals.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen lagrede måltider", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Åpne dagsloggen på Hjem og velg Gjenbruk → Lagre som måltid.")
                    }
                } else {
                    List {
                        if let error = viewModel.loadError {
                            ErrorMessageView(error)
                            Button("Prøv igjen") { Task { await viewModel.load(userId: authViewModel.currentUser?.id) } }
                        }
                        ForEach(viewModel.meals) { meal in
                            HStack {
                                Button { selectedMeal = meal } label: {
                                    SavedMealRow(meal: meal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Menu {
                                    Button("Rediger") { editingMeal = meal }
                                    Button("Slett", role: .destructive) { deleteCandidate = meal }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Valg for \(meal.name)")
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Slett", role: .destructive) { deleteCandidate = meal }
                                Button("Rediger") { editingMeal = meal }.tint(AppColors.action)
                            }
                            .contextMenu {
                                Button("Rediger") { editingMeal = meal }
                                Button("Slett", role: .destructive) { deleteCandidate = meal }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.load(userId: authViewModel.currentUser?.id) }
                }
            }
            .background(AppColors.background)
            .navigationTitle("Lagrede måltider")
            .toolbar {
                if viewModel.showsLoadingFeedback && !viewModel.meals.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        ActivityIndicatorSlot(isActive: true, label: "Oppdaterer måltider")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .task(id: authViewModel.currentUser?.id) {
                await viewModel.load(userId: authViewModel.currentUser?.id)
            }
            .sheet(item: $selectedMeal) { meal in
                SavedMealLogView(meal: meal) {
                    selectedMeal = nil
                    dismiss()
                    onLogged()
                }
            }
            .sheet(item: $editingMeal) { meal in
                SavedMealLogView(meal: meal, startsEditing: true, onLogged: onLogged)
            }
            .alert("Slette \(deleteCandidate?.name ?? "måltidet")?", isPresented: Binding(
                get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }
            )) {
                Button("Slett", role: .destructive) {
                    guard let meal = deleteCandidate else { return }
                    Task {
                        _ = await viewModel.delete(meal)
                        deleteCandidate = nil
                    }
                }
                Button("Avbryt", role: .cancel) { deleteCandidate = nil }
            } message: {
                Text("Tidligere loggføringer blir ikke slettet.")
            }
        }
    }
}

struct SavedMealLogView: View {
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    let meal: SavedMeal
    var startsEditing = false
    let onLogged: () -> Void
    var body: some View { SavedMealLogContent(viewModel: viewModel, meal: meal, startsEditing: startsEditing, onLogged: onLogged) }
}

private struct SavedMealLogContent: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let viewModel: SavedMealsViewModel
    @StateObject private var formState: SavedMealFormState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: PreferencesViewModel
    @StateObject private var detail: SavedMealDetailViewModel
    private var meal: SavedMeal { detail.meal }
    private let startsEditing: Bool
    @State private var didStart = false
    @State private var showDiscard = false
    @State private var closeAfterDiscard = false
    @StateObject private var itemsModel: SavedMealItemsViewModel
    let onLogged: () -> Void
    @StateObject private var nutritionModel: SavedMealNutritionPreviewViewModel
    @State private var isChoosingTarget = false

    init(viewModel: SavedMealsViewModel, meal: SavedMeal, startsEditing: Bool, onLogged: @escaping () -> Void) {
        _detail = StateObject(wrappedValue: SavedMealDetailViewModel(meal: meal))
        self.startsEditing = startsEditing
        self.viewModel = viewModel
        _formState = StateObject(wrappedValue: SavedMealFormState(viewModel: viewModel))
        self.onLogged = onLogged
        _itemsModel = StateObject(wrappedValue: viewModel.makeItemsViewModel(meal: meal))
        _nutritionModel = StateObject(wrappedValue: SavedMealNutritionPreviewViewModel(meal: meal))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MatLoggSheetHeader(title: detail.isEditing ? "Endre måltid" : meal.name,
                                   isCloseDisabled: formState.isSaving || formState.isLoadingPhoto) {
                    requestExit(close: true)
                }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Spacer()
                            Button(detail.isEditing ? "Avbryt" : "Rediger") {
                                if detail.isEditing { requestExit(close: false) }
                                else { beginEditing() }
                            }
                            .frame(minHeight: 44)
                            .disabled(formState.isSaving || formState.isLoadingPhoto)
                            .accessibilityIdentifier("saved-meal-edit-toggle")
                        }
                        if detail.isEditing {
                            TextField("Navn på måltidet", text: $detail.name)
                                .font(AppTypography.title)
                                .accessibilityIdentifier("saved-meal-edit-name")
                            SavedMealPhotoPicker()
                            Text("Endringene gjelder det lagrede måltidet. Tidligere loggføringer påvirkes ikke.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        } else if let data = meal.localImageData {
                            ProductHeroImageView(localData: data, height: 180)
                                .accessibilityLabel("Bilde av \(meal.name)")
                        }

                        if !detail.isEditing {
                            targetPicker
                            Text("Mengdeendringer her gjelder bare denne loggføringen.")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }

                        CardContainer {
                            let items = detail.isEditing ? detail.visibleItems : itemsModel.sortedItems
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(items) { item in
                                    if item.id != items.first?.id {
                                        Divider().overlay(AppColors.separator)
                                    }
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(alignment: .top, spacing: 12) {
                                            let product = itemsModel.imageProducts[item.productId]
                                            ProductThumbnailView(
                                                url: product?.imageUrl.flatMap(URL.init(string:)),
                                                localData: product?.localImageData,
                                                imagePadding: 2
                                            )
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.productName)
                                                    .font(AppTypography.bodyEmphasis)
                                                    .foregroundStyle(AppColors.deepInk)
                                                if preferences.showNutritionSource {
                                                    Text("Kilde: \(sourceLabel(item.nutritionSource))")
                                                        .font(AppTypography.caption)
                                                        .foregroundStyle(AppColors.textSecondary)
                                                }
                                            }
                                        }

                                        VStack(alignment: .leading, spacing: 8) {
                                            if dynamicTypeSize.isAccessibilitySize {
                                                Text("Mengde")
                                                    .font(AppTypography.bodyEmphasis)
                                                    .foregroundStyle(AppColors.ink)
                                            }
                                            AmountInputRow(
                                                gramsText: amountBinding(for: item),
                                                unit: item.resolvedAmountUnit.rawValue,
                                                placeholder: "0",
                                                showsTitle: !dynamicTypeSize.isAccessibilitySize,
                                                controlWidth: dynamicTypeSize.isAccessibilitySize ? 156 : 116,
                                                controlFill: AppColors.mutedSurface
                                            )
                                            .accessibilityElement(children: .contain)
                                            .accessibilityLabel(item.productName)
                                        }

                                        if detail.isEditing {
                                            Menu {
                                                Button("Fjern matvare", role: .destructive) { detail.remove(item) }
                                            } label: {
                                                Label("Valg", systemImage: "ellipsis.circle").frame(minHeight: 44)
                                            }
                                            .accessibilityLabel("Valg for \(item.productName)")
                                        }
                                        if let nutrition = activePreview.nutritionByItem[item.id] {
                                            SavedMealNutritionSummary(nutrition: nutrition)
                                                .accessibilityIdentifier("saved-meal-nutrition-\(item.id)")
                                        } else if let error = activePreview.errorsByItem[item.id] {
                                            Text(error)
                                                .font(AppTypography.caption)
                                                .foregroundStyle(AppColors.actionText)
                                        }
                                    }
                                }
                            }
                        }

                        if detail.isEditing && detail.visibleItems.isEmpty {
                            Text("Et lagret måltid må inneholde minst én matvare.")
                                .font(AppTypography.body)
                        }
                        if detail.isEditing && (detail.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || detail.name.count > 80) {
                            Text("Gi måltidet et navn på opptil 80 tegn.").font(AppTypography.caption)
                        }
                        CardContainer {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hele måltidet")
                                    .font(AppTypography.bodyEmphasis)
                                    .foregroundStyle(AppColors.deepInk)
                                if let total = activePreview.total {
                                    SavedMealNutritionSummary(nutrition: total)
                                        .accessibilityIdentifier("saved-meal-nutrition-total")
                                } else {
                                    Text("Totalen vises når alle varene har gyldig mengde og næringsgrunnlag.")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }
                .disabled(formState.isSaving)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let error = formState.errorMessage {
                        ErrorMessageView(error)
                            .font(AppTypography.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: primaryButtonTitle) {
                        Task {
                            if detail.isEditing { await saveChanges() }
                            else { await logMeal() }
                        }
                    }
                    .disabled((detail.isEditing ? !detail.canSave : nutritionModel.preview.validAmounts == nil)
                              || formState.isSaving || formState.isLoadingPhoto)
                    .accessibilityIdentifier("saved-meal-log")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppColors.background)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Ferdig") { hideKeyboard() }
                }
            }
            .interactiveDismissDisabled(formState.isSaving || detail.isEditing)
        }
        .alert("Forkaste endringene?", isPresented: $showDiscard) {
            Button("Forkast", role: .destructive) { finishEditing(close: closeAfterDiscard) }
            Button("Fortsett å redigere", role: .cancel) {}
        } message: { Text("Endringene er ikke lagret.") }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            if startsEditing { beginEditing() }
        }
        .onDisappear { if detail.isEditing { viewModel.beginPhotoEditing() } }
        .task(id: meal) {
            nutritionModel.update(meal)
            itemsModel.update(meal)
            await itemsModel.loadProductImages()
        }
        .presentationDragIndicator(.visible)
    }

    private var targetPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Logg til")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textSecondary)
                    Text("\(LogSummaryService.title(for: appState.selectedMealType)) · \(dateLabel)")
                        .font(AppTypography.bodyEmphasis)
                        .foregroundStyle(AppColors.deepInk)
                }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                Button(isChoosingTarget ? "Ferdig" : "Endre") {
                    isChoosingTarget.toggle()
                }
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.actionText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(isChoosingTarget ? "Skjul måltidsvalg" : "Endre måltid")
            }

            if isChoosingTarget {
                Divider().overlay(AppColors.separator)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { mealButtons }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        mealButtons
                    }
                }
            }
        }
        .padding(.horizontal, 4)
    }


    @ViewBuilder private var mealButtons: some View {
        ForEach(MealPresentation.all) { option in
            MealChip(
                title: option.title,
                isSelected: appState.selectedMealType == option.key,
                action: { appState.selectedMealType = option.key }
            )
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Logg til \(option.title)")
        }
    }

    private var activePreview: SavedMealNutritionPreview {
        detail.isEditing ? detail.nutrition.preview : nutritionModel.preview
    }

    private func beginEditing() {
        detail.beginEditing()
        viewModel.beginPhotoEditing(data: meal.localImageData)
    }

    private func requestExit(close: Bool) {
        guard !formState.isSaving && !formState.isLoadingPhoto else { return }
        if detail.isEditing && detail.hasChanges(photoData: viewModel.photoData) {
            closeAfterDiscard = close
            showDiscard = true
        } else { finishEditing(close: close) }
    }

    private func finishEditing(close: Bool) {
        if detail.isEditing {
            detail.cancelEditing()
            viewModel.beginPhotoEditing()
        }
        if close { dismiss() }
    }

    private func saveChanges() async {
        if await detail.save(using: viewModel) {
            nutritionModel.reset(meal)
            itemsModel.update(meal)
            viewModel.beginPhotoEditing()
        }
    }

    private var primaryButtonTitle: String {
        if detail.isEditing { return formState.isSaving ? "Lagrer …" : "Lagre endringer" }
        if formState.isSaving { return "Logger …" }
        return "Loggfør måltidet"
    }

    private func amountBinding(for item: SavedMealItem) -> Binding<String> {
        Binding(get: { activePreview.amountTexts[item.id] ?? "" },
                set: { text in
                    if detail.isEditing { detail.nutrition.setAmount(itemID: item.id, text: text) }
                    else { nutritionModel.setAmount(itemID: item.id, text: text) }
                })
    }

    private func logMeal() async {
        guard let userId = authViewModel.currentUser?.id, let parsedAmounts = nutritionModel.preview.validAmounts else { return }
        if await viewModel.log(
            meal,
            mealType: appState.selectedMealType,
            date: appState.logSelectedDate,
            amounts: parsedAmounts,
            userId: userId
        ) {
            onLogged()
        }
    }

    private var dateLabel: String {
        let date = appState.logSelectedDate
        if Calendar.current.isDateInToday(date) { return "I dag" }
        if Calendar.current.isDateInYesterday(date) { return "I går" }
        if Calendar.current.isDateInTomorrow(date) { return "I morgen" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "nb_NO")))
    }
}

private struct SavedMealNutritionSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let nutrition: NutritionBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(nutrition.calories.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "nb_NO")))) kcal")
                .font(AppTypography.bodyEmphasis)
                .foregroundStyle(AppColors.deepInk)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            layout {
                Text("Protein \(grams(nutrition.protein)) g")
                Text("Karbohydrat \(grams(nutrition.carbs)) g")
                Text("Fett \(grams(nutrition.fat)) g")
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func grams(_ value: Float) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "nb_NO")))
    }
}

struct SavedMealRow: View {
    let meal: SavedMeal
    @StateObject private var itemsModel: SavedMealItemsViewModel

    init(meal: SavedMeal) {
        self.meal = meal
        _itemsModel = StateObject(wrappedValue: SavedMealItemsViewModel(meal: meal))
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = meal.localImageData {
                    ProductThumbnailView(url: nil, localData: data, size: 44, imagePadding: 0)
                } else {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(AppColors.actionText)
                        .frame(width: 44, height: 44)
                        .background(AppColors.mutedSurface, in: Circle())
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(AppTypography.bodyEmphasis).foregroundStyle(AppColors.deepInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(itemsModel.subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(AppColors.textSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Åpner måltidet før loggføring")
        .onChange(of: meal) { _, meal in itemsModel.update(meal) }
    }

}

struct SavedMealToastView: View {
    let receipt: SavedMealReceipt
    let isUndoing: Bool
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.success)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(receipt.mealName) lagt til i \(LogSummaryService.title(for: receipt.mealType))")
                    .font(AppTypography.bodyEmphasis)
                Text("Lagret på enheten").font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button(isUndoing ? "Angrer …" : "Angre", action: onUndo)
                .font(AppTypography.bodyEmphasis)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isUndoing)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppColors.separator))
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Lukk bekreftelse", onDismiss)
    }
}

private func format(_ amount: Float) -> String {
    amount.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "nb_NO")))
}

private func sourceLabel(_ source: NutritionSource) -> String {
    switch source {
    case .matvaretabellen: return "Matvaretabellen"
    case .openFoodFacts: return "Open Food Facts"
    case .user: return "Brukeroppgitt"
    }
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private struct SavedMealPhotoPicker: View {
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    @State private var selection: PhotosPickerItem?

    var body: some View {
        let pickerTitle = viewModel.photoData == nil ? "Legg ved bilde" : "Bytt bilde"
        return VStack(alignment: .leading, spacing: 8) {
            Text("Bilde (valgfritt)")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.deepInk)
            if let image = viewModel.photoPreview {
                ProductHeroImageView(image: image, height: 160)
                    .accessibilityLabel("Valgt måltidsbilde")
            }
            PhotosPicker(selection: $selection, matching: .images) {
                Label(pickerTitle, systemImage: "photo")
                    .font(AppTypography.bodyEmphasis)
                    .frame(minHeight: 44)
            }
            .foregroundStyle(AppColors.actionText)
            .accessibilityIdentifier("saved-meal-photo-picker")
            if viewModel.photoData != nil || viewModel.isLoadingPhoto {
                Button("Fjern bilde", role: .destructive) {
                    selection = nil
                    viewModel.beginPhotoEditing()
                }
                .font(AppTypography.body)
                .frame(minHeight: 44)
                .accessibilityIdentifier("saved-meal-photo-remove")
            }
            if viewModel.isLoadingPhoto { ProgressView("Åpner bilde …") }
            if let error = viewModel.photoError {
                ErrorMessageView(error).font(AppTypography.caption)
            }
            Text("Bildet lagres bare på denne enheten og synkroniseres ikke.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .onChange(of: selection) { _, item in
            if let item { Task { await viewModel.loadPhoto(item) } }
        }
    }
}
