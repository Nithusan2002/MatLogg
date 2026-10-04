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
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.action)
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
                        Text(error)
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
                        if viewModel.isLoading { ProgressView("Oppdaterer måltider …") }
                        if let error = viewModel.loadError {
                            Text(error)
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
                }
            }
            .background(AppColors.background)
            .navigationTitle("Lagrede måltider")
            .toolbar {
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
                SavedMealEditorView(meal: meal)
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
    let onLogged: () -> Void
    var body: some View { SavedMealLogContent(viewModel: viewModel, meal: meal, onLogged: onLogged) }
}

private struct SavedMealLogContent: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SavedMealsViewModel
    @StateObject private var formState: SavedMealFormState
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: PreferencesViewModel
    let meal: SavedMeal
    @StateObject private var itemsModel: SavedMealItemsViewModel
    let onLogged: () -> Void
    @State private var amounts: [UUID: String] = [:]
    @State private var isChoosingTarget = false

    init(viewModel: SavedMealsViewModel, meal: SavedMeal, onLogged: @escaping () -> Void) {
        self.meal = meal
        self.viewModel = viewModel
        _formState = StateObject(wrappedValue: SavedMealFormState(viewModel: viewModel))
        self.onLogged = onLogged
        _itemsModel = StateObject(wrappedValue: SavedMealItemsViewModel(meal: meal))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MatLoggSheetHeader(title: meal.name, isCloseDisabled: formState.isSaving) { dismiss() }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let data = meal.localImageData {
                            ProductHeroImageView(localData: data, height: 180)
                                .accessibilityLabel("Bilde av \(meal.name)")
                        }

                        targetPicker

                        ForEach(itemsModel.sortedItems) { item in
                            CardContainer {
                                VStack(alignment: .leading, spacing: 12) {
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

                                    Divider().overlay(AppColors.separator)

                                    AmountInputRow(
                                        gramsText: amountBinding(for: item),
                                        unit: item.resolvedAmountUnit.rawValue,
                                        placeholder: "0"
                                    )

                                    if let text = amounts[item.id], !text.isEmpty, parsedAmount(text) == nil {
                                        Text("Bruk en mengde over 0 og høyst 10 000 \(item.resolvedAmountUnit.rawValue).")
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppColors.action)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .disabled(formState.isSaving)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let error = formState.errorMessage {
                        Text(error)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.action)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(title: primaryButtonTitle) {
                        Task { await logMeal() }
                    }
                    .disabled(parsedAmounts == nil || formState.isSaving)
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
            .onAppear {
                amounts = Dictionary(uniqueKeysWithValues: meal.items.map {
                    ($0.id, format($0.amountG))
                })
            }
            .interactiveDismissDisabled(formState.isSaving)
        }
        .onChange(of: meal) { _, meal in itemsModel.update(meal) }
        .presentationDragIndicator(.visible)
    }

    private var targetPicker: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Logg til")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                        Text("\(LogSummaryService.title(for: appState.selectedMealType)) · \(dateLabel)")
                            .font(AppTypography.bodyEmphasis)
                            .foregroundStyle(AppColors.deepInk)
                    }
                    Spacer()
                    Button(isChoosingTarget ? "Ferdig" : "Endre") {
                        isChoosingTarget.toggle()
                    }
                    .font(AppTypography.bodyEmphasis)
                    .foregroundStyle(AppColors.action)
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
        }
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

    private var primaryButtonTitle: String {
        if formState.isSaving { return "Logger …" }
        return meal.items.count == 1 ? "Loggfør varen" : "Loggfør \(meal.items.count) varer"
    }

    private var parsedAmounts: [UUID: Float]? {
        var result: [UUID: Float] = [:]
        for item in meal.items {
            guard let text = amounts[item.id], let value = parsedAmount(text) else { return nil }
            result[item.id] = value
        }
        return result
    }

    private func parsedAmount(_ text: String) -> Float? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Float(normalized), value.isFinite, value > 0, value <= 10_000 else { return nil }
        return value
    }

    private func amountBinding(for item: SavedMealItem) -> Binding<String> {
        Binding(get: { amounts[item.id] ?? "" }, set: { amounts[item.id] = $0 })
    }

    private func logMeal() async {
        guard let userId = authViewModel.currentUser?.id, let parsedAmounts else { return }
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

struct SavedMealEditorView: View {
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    let meal: SavedMeal

    var body: some View { SavedMealEditorContent(viewModel: viewModel, meal: meal) }
}

private struct SavedMealEditorContent: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: SavedMealsViewModel
    @StateObject private var formState: SavedMealFormState
    let meal: SavedMeal
    @StateObject private var itemsModel: SavedMealItemsViewModel
    @State private var name = ""
    @State private var amounts: [UUID: String] = [:]
    private var removed: Set<UUID> { itemsModel.removed }

    init(viewModel: SavedMealsViewModel, meal: SavedMeal) {
        self.meal = meal
        self.viewModel = viewModel
        _formState = StateObject(wrappedValue: SavedMealFormState(viewModel: viewModel))
        _itemsModel = StateObject(wrappedValue: SavedMealItemsViewModel(meal: meal))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Navn") { TextField("Navn", text: $name) }
                Section { SavedMealPhotoPicker().disabled(formState.isSaving) }
                    .listRowBackground(AppColors.surface)
                Section("Matvarer") {
                    ForEach(itemsModel.visibleItems) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.productName).font(AppTypography.bodyEmphasis)
                            TextField("Mengde i \(item.resolvedAmountUnit.spokenName)", text: Binding(
                                get: { amounts[item.id] ?? "" }, set: { amounts[item.id] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            Button("Fjern matvare", role: .destructive) { itemsModel.removed.insert(item.id) }
                                .frame(minHeight: 44)
                        }
                    }
                }
                if meal.items.count == removed.count {
                    Section { Text("Et lagret måltid må inneholde minst én matvare.") }
                }
                if let error = formState.errorMessage { Section { Text(error) } }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.background.ignoresSafeArea())
            .font(AppTypography.body)
            .foregroundStyle(AppColors.ink)
            .navigationTitle("Endre måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(formState.isSaving ? "Lagrer …" : "Lagre") { Task { await save() } }
                        .disabled(formState.isSaving || formState.isLoadingPhoto || parsedAmounts == nil || meal.items.count == removed.count)
                }
            }
            .onAppear {
                viewModel.beginPhotoEditing(data: meal.localImageData)
                name = meal.name
                amounts = Dictionary(uniqueKeysWithValues: meal.items.map { ($0.id, format($0.amountG)) })
            }
            .onDisappear { viewModel.beginPhotoEditing() }
            .interactiveDismissDisabled(formState.isSaving)
        }
        .onChange(of: meal) { _, meal in itemsModel.update(meal) }
        .tint(AppColors.action)
    }

    private var parsedAmounts: [UUID: Float]? {
        var result: [UUID: Float] = [:]
        for item in meal.items where !removed.contains(item.id) {
            guard let text = amounts[item.id], let value = Float(text.replacingOccurrences(of: ",", with: ".")),
                  value.isFinite, value > 0, value <= 10_000 else { return nil }
            result[item.id] = value
        }
        return result
    }

    private func save() async {
        guard let parsedAmounts else { return }
        if await viewModel.update(meal, name: name, amounts: parsedAmounts, removedItemIDs: removed) {
            dismiss()
        }
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
                        .foregroundStyle(AppColors.action)
                        .frame(width: 44, height: 44)
                        .background(AppColors.mutedSurface, in: Circle())
                }
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(AppTypography.bodyEmphasis).foregroundStyle(AppColors.deepInk)
                Text(itemsModel.subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2)
            }
            Spacer()
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
            .foregroundStyle(AppColors.action)
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
                Text(error).font(AppTypography.caption).foregroundStyle(AppColors.action)
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
