import Foundation
import Combine

/// One manual logging session, shared across its entry points and scoped to the active profile.
@MainActor
final class FoodLoggingDraftViewModel: ObservableObject {
    @Published private(set) var draft: FoodLoggingDraft?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var isLoaded = false
    @Published private(set) var manualModel: ManualProductViewModel?
    @Published private(set) var amountModel: AmountSelectionViewModel?
    private let repository: any FoodLoggingDraftRepository
    private var owner: UUID?
    private var generation = UUID()
    private var autosave: Task<Void, Never>?
    private var loadTask: Task<Result<FoodLoggingDraft?, Error>, Never>?
    private var writes: Task<Bool, Never>?
    private var amountObservation: AnyCancellable?
    private var acceptingChanges = false

    init(repository: any FoodLoggingDraftRepository) { self.repository = repository }

    func load(owner: UUID?) async {
        guard self.owner != owner || !isLoaded else { return }
        if self.owner != owner || loadTask == nil {
            generation = UUID()
            acceptingChanges = false
            autosave?.cancel()
            manualModel?.inputChanged = nil
            amountObservation = nil
            self.owner = owner
            draft = nil; manualModel = nil; amountModel = nil
            isLoaded = false; errorMessage = nil; isBusy = false
            let previous = writes
            let repository = repository
            loadTask = Task {
                _ = await previous?.value
                guard let owner else { return .success(nil) }
                do { return .success(try await repository.loadLoggingDraft(owner: owner)) }
                catch { return .failure(error) }
            }
        }
        let request = generation
        guard let task = loadTask else { return }
        let result = await task.value
        guard generation == request else { return }
        // Concurrent entry points await the same load and can safely observe its result.
        if isLoaded { return }
        switch result {
        case .success(let loaded):
            draft = loaded; configureModels(); isLoaded = true
        case .failure:
            errorMessage = "Kunne ikke åpne utkastet. Dataene er beholdt. Prøv igjen."
            loadTask = nil
        }
    }

    func start(barcode: String?, mealType: String, date: Date) async -> Bool {
        guard isLoaded, let owner, !isBusy else { return false }
        if draft != nil { return true } // The entry view offers Continue/Forkast before presenting it.
        isBusy = true
        let request = generation
        defer { if generation == request { isBusy = false } }
        let newDraft = FoodLoggingDraft(userId: owner, barcode: barcode, mealType: mealType, date: date)
        do {
            try await repository.createLoggingDraft(newDraft)
            guard generation == request else { return false }
            draft = newDraft; configureModels(); errorMessage = nil
            return true
        } catch {
            if generation == request { errorMessage = "Kunne ikke opprette utkastet. Prøv igjen." }
            return false
        }
    }

    private func configureModels() {
        acceptingChanges = false
        manualModel?.inputChanged = nil
        amountObservation = nil
        guard let draft else { manualModel = nil; amountModel = nil; return }
        let manual = ManualProductViewModel(barcode: draft.barcode) { [weak self] product in
            guard let self else { throw LoggingDraftError.unavailable }
            try await self.advance(product)
        }
        manual.restoreInput(draft.input, productID: draft.productId)
        manual.inputChanged = { [weak self] in self?.changed() }
        manualModel = manual
        if let product = draft.product {
            let amount = AmountSelectionViewModel(unit: product.amountUnit, servings: product.servings ?? [])
            if let serving = draft.selectedServing { amount.select(serving) }
            amount.text = draft.amountText
            amountModel = amount
            // @Published fires before assignment; defer the snapshot until the new value is visible.
            amountObservation = amount.objectWillChange.sink { [weak self] in
                Task { @MainActor in self?.changed() }
            }
        } else { amountModel = nil }
        acceptingChanges = true
    }

    private func capture() -> FoodLoggingDraft? {
        guard var snapshot = draft else { return nil }
        if snapshot.step == .product, let manualModel { snapshot.input = manualModel.input }
        if snapshot.step == .amount, let amountModel {
            snapshot.amountText = amountModel.text
            snapshot.selectedServing = amountModel.selectedServing
        }
        snapshot.revision += 1
        snapshot.updatedAt = Date()
        draft = snapshot
        return snapshot
    }

    private func changed() {
        guard acceptingChanges, !isBusy else { return }
        autosave?.cancel()
        let request = generation
        autosave = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self, self.generation == request else { return }
            _ = await self.flush()
        }
    }

    @discardableResult
    func flush() async -> Bool {
        autosave?.cancel()
        guard acceptingChanges, let snapshot = capture() else { return draft == nil }
        let previous = writes
        let request = generation
        let repository = repository
        let write = Task { [weak self] in
            _ = await previous?.value
            guard let self, self.generation == request else { return false }
            do {
                try await repository.updateLoggingDraft(snapshot)
                if self.generation == request { self.errorMessage = nil }
                return true
            } catch {
                if self.generation == request { self.errorMessage = "Kunne ikke lagre utkastet på enheten. Prøv igjen." }
                return false
            }
        }
        writes = write
        return await write.value
    }

    private func advance(_ product: Product) async throws {
        guard !isBusy, draft?.step == .product else { throw LoggingDraftError.conflict }
        isBusy = true; acceptingChanges = false
        autosave?.cancel()
        let request = generation
        defer { if generation == request { isBusy = false; acceptingChanges = true } }
        _ = await writes?.value
        guard generation == request, var snapshot = capture() else { throw LoggingDraftError.conflict }
        snapshot.step = .amount; snapshot.product = product
        try await repository.advanceLoggingDraft(snapshot, product: product)
        guard generation == request else { throw LoggingDraftError.conflict }
        draft = snapshot
        configureModels()
    }

    func setDate(_ date: Date) { guard !isBusy else { return }; draft?.date = date; changed() }
    func setMealType(_ type: String) { guard !isBusy else { return }; draft?.mealType = type; changed() }

    func discard() async -> Bool {
        guard !isBusy, let draft else { return false }
        isBusy = true; acceptingChanges = false; autosave?.cancel()
        let request = generation
        defer { if generation == request { isBusy = false; acceptingChanges = true } }
        _ = await writes?.value
        guard generation == request else { return false }
        do {
            try await repository.discardLoggingDraft(id: draft.id, owner: draft.userId)
            guard generation == request else { return false }
            self.draft = nil; configureModels(); errorMessage = nil
            return true
        } catch {
            if generation == request { errorMessage = "Kunne ikke forkaste utkastet. Prøv igjen." }
            return false
        }
    }

    func complete() async -> ReceiptPayload? {
        guard !isBusy, let amountModel, amountModel.isValid, let amount = amountModel.amount,
              let product = draft?.product else { return nil }
        guard let nutrition = NutritionCalculator.validatedCalculation(
            per100: NutritionBreakdown(calories: product.caloriesPer100g, protein: product.proteinGPer100g,
                                       carbs: product.carbsGPer100g, fat: product.fatGPer100g), amount: Float(amount)) else {
            errorMessage = "Kunne ikke lagre: Sjekk mengden og næringstallene."
            return nil
        }
        isBusy = true; acceptingChanges = false; autosave?.cancel()
        let request = generation
        defer { if generation == request { isBusy = false; acceptingChanges = true } }
        _ = await writes?.value
        guard generation == request, let snapshot = capture() else { return nil }
        let log = FoodLog(id: snapshot.logId, userId: snapshot.userId, productId: snapshot.productId,
                          mealType: snapshot.mealType, amountG: Float(amount), amountUnit: product.amountUnit,
                          portionSelection: amountModel.portion, loggedDate: Calendar.current.startOfDay(for: snapshot.date),
                          calories: nutrition.calories, proteinG: nutrition.protein,
                          carbsG: nutrition.carbs, fatG: nutrition.fat)
        do {
            try await repository.completeLoggingDraft(snapshot, log: log)
            guard generation == request else { return nil }
            draft = nil; configureModels(); errorMessage = nil
            return ReceiptPayload(product: product, amountG: amount, amountUnit: product.amountUnit, mealType: snapshot.mealType,
                                  loggedDate: log.loggedDate, portionSelection: log.portionSelection,
                                  logID: log.id, ownerID: log.userId)
        } catch {
            if generation == request { errorMessage = "Kunne ikke lagre på enheten. Prøv igjen." }
            return nil
        }
    }
}
