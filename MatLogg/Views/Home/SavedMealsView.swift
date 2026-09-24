import SwiftUI
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Navn") {
                    TextField("For eksempel Vanlig frokost", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("saved-meal-name")
                }
                Section {
                    ForEach(source.logs) { log in
                        HStack {
                            Text(productName(for: log))
                            Spacer()
                            Text("\(format(log.amountG)) g")
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                } header: {
                    Text("Innhold")
                } footer: {
                    Text("Mengder og næringsgrunnlag lagres slik de er registrert nå. Tidligere logger endres ikke.")
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(AppColors.ink) }
                }
            }
            .navigationTitle("Lagre som måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                        .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Lagrer …" : "Lagre") {
                        Task { await save() }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
                    .accessibilityIdentifier("saved-meal-save")
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .task {
                if let userId = authViewModel.currentUser?.id {
                    await viewModel.load(userId: userId)
                }
            }
        }
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
        productViewModel.product(id: log.productId)?.name ?? "Ukjent matvare"
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
                if viewModel.meals.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen lagrede måltider", systemImage: "square.stack.3d.up")
                    } description: {
                        Text("Åpne et måltid i loggen og velg «Lagre som måltid».")
                    }
                } else {
                    List {
                        ForEach(viewModel.meals) { meal in
                            Button { selectedMeal = meal } label: {
                                SavedMealRow(meal: meal)
                            }
                            .buttonStyle(.plain)
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
            .task {
                if let userId = authViewModel.currentUser?.id { await viewModel.load(userId: userId) }
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var preferences: PreferencesViewModel
    let meal: SavedMeal
    let onLogged: () -> Void
    @State private var amounts: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Kontroller mengdene før du loggfører.")
                        .font(AppTypography.body)
                        .foregroundStyle(AppColors.textSecondary)

                    targetPicker

                    ForEach(meal.items.sorted(by: { $0.sortIndex < $1.sortIndex })) { item in
                        CardContainer {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(item.productName).font(AppTypography.bodyEmphasis)
                                if preferences.showNutritionSource {
                                    Text("Kilde: \(sourceLabel(item.nutritionSource))")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                TextField("Mengde i gram", text: amountBinding(for: item))
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(.roundedBorder)
                                    .accessibilityLabel("Mengde i gram for \(item.productName)")
                            }
                        }
                    }

                    if let error = viewModel.errorMessage {
                        Text(error).font(AppTypography.body).foregroundStyle(AppColors.ink)
                    }

                    PrimaryButton(title: viewModel.isSaving ? "Lagrer …" : "Loggfør måltidet") {
                        Task { await logMeal() }
                    }
                    .disabled(parsedAmounts == nil || viewModel.isSaving)
                    .accessibilityIdentifier("saved-meal-log")
                }
                .padding(16)
            }
            .background(AppColors.background)
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }.disabled(viewModel.isSaving)
                }
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
            .interactiveDismissDisabled(viewModel.isSaving)
        }
    }

    private var targetPicker: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Text("Logg til: \(LogSummaryService.title(for: appState.selectedMealType))")
                    .font(AppTypography.bodyEmphasis)
                Label(dateLabel, systemImage: "calendar")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) { mealButtons }
                    VStack(spacing: 6) { mealButtons }
                }
            }
        }
    }

    @ViewBuilder private var mealButtons: some View {
        ForEach(MealPresentation.all) { option in
            Button {
                appState.selectedMealType = option.key
            } label: {
                Text(option.title)
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(appState.selectedMealType == option.key ? AppColors.onVibrant : AppColors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(appState.selectedMealType == option.key ? AppColors.brand : AppColors.mutedSurface, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(appState.selectedMealType == option.key ? .isSelected : [])
        }
    }

    private var parsedAmounts: [UUID: Float]? {
        var result: [UUID: Float] = [:]
        for item in meal.items {
            guard let text = amounts[item.id],
                  let value = Float(text.replacingOccurrences(of: ",", with: ".")),
                  value.isFinite, value > 0, value <= 10_000 else { return nil }
            result[item.id] = value
        }
        return result
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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: SavedMealsViewModel
    let meal: SavedMeal
    @State private var name = ""
    @State private var amounts: [UUID: String] = [:]
    @State private var removed = Set<UUID>()

    var body: some View {
        NavigationStack {
            Form {
                Section("Navn") { TextField("Navn", text: $name) }
                Section("Matvarer") {
                    ForEach(meal.items.sorted(by: { $0.sortIndex < $1.sortIndex }).filter { !removed.contains($0.id) }) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.productName).font(AppTypography.bodyEmphasis)
                            TextField("Mengde i gram", text: Binding(
                                get: { amounts[item.id] ?? "" }, set: { amounts[item.id] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            Button("Fjern matvare", role: .destructive) { removed.insert(item.id) }
                                .frame(minHeight: 44)
                        }
                    }
                }
                if meal.items.count == removed.count {
                    Section { Text("Et lagret måltid må inneholde minst én matvare.") }
                }
                if let error = viewModel.errorMessage { Section { Text(error) } }
            }
            .navigationTitle("Endre måltid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Avbryt") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Lagrer …" : "Lagre") { Task { await save() } }
                        .disabled(viewModel.isSaving || parsedAmounts == nil || meal.items.count == removed.count)
                }
            }
            .onAppear {
                name = meal.name
                amounts = Dictionary(uniqueKeysWithValues: meal.items.map { ($0.id, format($0.amountG)) })
            }
            .interactiveDismissDisabled(viewModel.isSaving)
        }
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.stack.3d.up.fill")
                .foregroundStyle(AppColors.action)
                .frame(width: 44, height: 44)
                .background(AppColors.mutedSurface, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name).font(AppTypography.bodyEmphasis).foregroundStyle(AppColors.deepInk)
                Text(subtitle).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(AppColors.textSecondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Åpner måltidet før loggføring")
    }

    private var subtitle: String {
        let names = meal.items.sorted(by: { $0.sortIndex < $1.sortIndex }).prefix(3).map(\.productName)
        let suffix = meal.items.count > 3 ? " + \(meal.items.count - 3) til" : ""
        return names.joined(separator: ", ") + suffix
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
