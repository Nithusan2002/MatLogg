import SwiftUI
import Foundation
import Combine
import PhotosUI
import UIKit

struct SavedMealReceipt: Equatable {
    let mealName: String
    let mealType: String
    let logIDs: [UUID]
    let userId: UUID
    let date: Date
}

@MainActor
final class SavedMealsViewModel: ObservableObject {
    @Published private(set) var meals: [SavedMeal] = []
    @Published private(set) var isLoading = true {
        didSet {
            loadingFeedback.update(isActive: isLoading) { [weak self] in self?.showsLoadingFeedback = $0 }
        }
    }
    @Published private(set) var showsLoadingFeedback = false
    private let loadingFeedback = DelayedActivity()
    @Published private(set) var loadError: String?
    @Published private(set) var isLoadingSource = true
    @Published private(set) var sourceProductNames: [UUID: String] = [:]
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var receipt: SavedMealReceipt?
    @Published private(set) var mutationRevision = 0

    private let savedMealRepository: any SavedMealRepository
    private let foodLogRepository: any FoodLogRepository
    @Published private(set) var photoData: Data?
    @Published private(set) var photoPreview: UIImage?
    @Published private(set) var isLoadingPhoto = false
    @Published private(set) var photoError: String?
    private var photoRequestID = UUID()
    private let photoRepository: any MealPhotoRepository

    private let calendar: Calendar
    private let now: () -> Date
    private var userId: UUID?
    private var contextID = UUID()
    private var isPreparingMutation = false
    private var loadID = UUID()
    private var sourceID = UUID()

    init(
        savedMealRepository: any SavedMealRepository,
        foodLogRepository: any FoodLogRepository,
        photoRepository: any MealPhotoRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.savedMealRepository = savedMealRepository
        self.foodLogRepository = foodLogRepository
        self.photoRepository = photoRepository
        self.calendar = calendar
        self.now = now
    }

    func makeItemsViewModel(meal: SavedMeal) -> SavedMealItemsViewModel {
        SavedMealItemsViewModel(meal: meal, repository: foodLogRepository)
    }

    func beginPhotoEditing(data: Data? = nil) {
        photoRequestID = UUID()
        photoData = data
        photoPreview = nil
        isLoadingPhoto = false
        photoError = nil
        if let data {
            let requestID = photoRequestID
            isLoadingPhoto = true
            Task { [weak self] in
                let preview = try? await ProductImagePreparation.image(from: data)
                guard let self, photoRequestID == requestID else { return }
                photoPreview = preview
                isLoadingPhoto = false
                if preview == nil { photoError = "Kunne ikke åpne bildet. Prøv et annet bilde." }
            }
        }
    }

    func loadPhoto(_ item: PhotosPickerItem) async {
        await importPhoto {
            try await self.photoRepository.loadPhoto { try await item.loadTransferable(type: Data.self) }
        }
    }

    // Injectable operation also lets tests exercise overlapping selections and failures.
    func importPhoto(_ operation: () async throws -> Data) async {
        let requestID = UUID()
        photoRequestID = requestID
        isLoadingPhoto = true
        photoError = nil
        defer { if photoRequestID == requestID { isLoadingPhoto = false } }
        do {
            let data = try await operation()
            guard requestID == photoRequestID else { return }
            let image = try await ProductImagePreparation.image(from: data)
            guard requestID == photoRequestID, !Task.isCancelled else { return }
            photoData = data
            photoPreview = image
            isLoadingPhoto = false
        } catch {
            guard requestID == photoRequestID else { return }
            isLoadingPhoto = false
            photoError = "Kunne ikke åpne bildet. Prøv et annet bilde."
        }
    }

    func reset() {
        beginPhotoEditing()
        contextID = UUID()
        loadID = UUID()
        sourceID = UUID()
        isLoading = true
        loadError = nil
        sourceProductNames = [:]
        isLoadingSource = true
        userId = nil
        meals = []
        receipt = nil
        errorMessage = nil
    }

    func load(userId: UUID?) async {
        if self.userId != userId {
            beginPhotoEditing()
            contextID = UUID()
            meals = []
            receipt = nil
            errorMessage = nil
        }
        let context = contextID
        self.userId = userId
        let request = UUID()
        loadID = request
        isLoading = true
        loadError = nil
        defer { if loadID == request { isLoading = false } }
        guard let userId else { meals = []; return }
        do {
            let loaded = try await savedMealRepository.loadSavedMeals(userId: userId)
            guard loadID == request, context == contextID, self.userId == userId, !Task.isCancelled else { return }
            meals = loaded
        } catch {
            guard loadID == request, context == contextID, !Task.isCancelled else { return }
            loadError = "Kunne ikke hente lagrede måltider. Prøv igjen."
        }
    }

    func loadCreationSource(logs: [FoodLog], userId: UUID?) async {
        if self.userId != userId { reset(); self.userId = userId }
        let request = UUID()
        sourceID = request
        isLoadingSource = true
        sourceProductNames = [:]
        defer { if sourceID == request { isLoadingSource = false } }
        let products = await foodLogRepository.getProducts(Set(logs.filter { $0.userId == userId }.map(\.productId)))
        guard sourceID == request, self.userId == userId, !Task.isCancelled else { return }
        sourceProductNames = products.mapValues(\.name)
    }

    @discardableResult
    func saveFromLogs(name: String, mealType: String, logs: [FoodLog], userId: UUID) async -> Bool {
        guard !isSaving, !isPreparingMutation, !isLoadingPhoto else { return false }
        let cleanName = normalizedName(name)
        guard let cleanName else {
            errorMessage = "Gi det lagrede måltidet et navn på opptil 80 tegn."
            return false
        }
        guard validMealType(mealType), !logs.isEmpty, logs.count <= 50,
              logs.allSatisfy({ $0.userId == userId }) else {
            errorMessage = "Måltidet må inneholde mellom 1 og 50 gyldige matvarer."
            return false
        }

        isPreparingMutation = true
        defer { isPreparingMutation = false }
        let context = contextID
        let photo = photoData
        let products = await foodLogRepository.getProducts(Set(logs.map(\.productId)))
        guard contextID == context, self.userId == userId, !Task.isCancelled else { return false }
        var items: [SavedMealItem] = []
        for (index, log) in logs.sorted(by: { $0.loggedTime < $1.loggedTime }).enumerated() {
            guard valid(log: log), let product = products[log.productId] else {
                errorMessage = "Vi mangler opplysninger om en av matvarene og kan ikke lagre måltidet."
                return false
            }
            items.append(SavedMealItem(
                productId: log.productId,
                productName: product.name,
                amountG: log.amountG,
                amountUnit: log.resolvedAmountUnit,
                portionSelection: log.portionSelection,
                calories: log.calories,
                proteinG: log.proteinG,
                carbsG: log.carbsG,
                fatG: log.fatG,
                nutritionSource: product.nutritionSource,
                sortIndex: index
            ))
        }

        isPreparingMutation = false
        return await save(SavedMeal(
            userId: userId,
            name: cleanName,
            suggestedMealType: mealType,
            items: items,
            localImageData: photo
        ))
    }

    @discardableResult
    func update(_ meal: SavedMeal, name: String, amounts: [UUID: Float], removedItemIDs: Set<UUID>, addedItems: [SavedMealItem] = []) async -> Bool {
        guard !isSaving, !isPreparingMutation, !isLoadingPhoto else { return false }
        guard meal.userId == userId else {
            errorMessage = "Måltidet tilhører en annen bruker."
            return false
        }
        guard let cleanName = normalizedName(name) else {
            errorMessage = "Gi det lagrede måltidet et navn på opptil 80 tegn."
            return false
        }
        let kept = (meal.items + addedItems).filter { !removedItemIDs.contains($0.id) }
        guard !kept.isEmpty else {
            errorMessage = "Et lagret måltid må inneholde minst én matvare."
            return false
        }

        var updatedItems: [SavedMealItem] = []
        for (index, original) in kept.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated() {
            guard let amount = amounts[original.id], valid(amount: amount) else {
                errorMessage = "Alle mengder må være større enn 0 og høyst 10 000 i oppgitt enhet."
                return false
            }
            guard let nutrition = NutritionCalculator.scaledSnapshot(
                calories: original.calories,
                protein: original.proteinG,
                carbs: original.carbsG,
                fat: original.fatG,
                from: original.amountG,
                to: amount
            ) else { return false }
            var item = original
            item.portionSelection = original.portionSelection?.scaled(to: amount)
            item.amountG = amount
            item.calories = nutrition.calories
            item.proteinG = nutrition.protein
            item.carbsG = nutrition.carbs
            item.fatG = nutrition.fat
            item.sortIndex = index
            updatedItems.append(item)
        }

        var updated = meal
        updated.localImageData = photoData
        updated.name = cleanName
        updated.items = updatedItems
        updated.updatedAt = now()
        return await save(updated)
    }

    @discardableResult
    func delete(_ meal: SavedMeal) async -> Bool {
        guard !isSaving, !isPreparingMutation, meal.userId == userId else { return false }
        isSaving = true
        let context = contextID
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await savedMealRepository.deleteSavedMeal(meal.id, userId: meal.userId)
            guard context == contextID, userId == meal.userId else { return true }
            meals.removeAll { $0.id == meal.id }
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "Kunne ikke slette det lagrede måltidet. Prøv igjen."
            return false
        }
    }

    @discardableResult
    func log(
        _ meal: SavedMeal,
        mealType: String,
        date: Date,
        amounts: [UUID: Float],
        userId: UUID
    ) async -> Bool {
        guard !isSaving, !isPreparingMutation, meal.userId == userId, self.userId == userId,
              validMealType(mealType), !meal.items.isEmpty else { return false }
        errorMessage = nil

        isPreparingMutation = true
        defer { isPreparingMutation = false }
        let preparationContext = contextID
        let products = await foodLogRepository.getProducts(Set(meal.items.map(\.productId)))
        guard contextID == preparationContext, self.userId == userId, !Task.isCancelled else { return false }
        let timestamp = now()
        let targetDate = calendar.startOfDay(for: date)
        var logs: [FoodLog] = []
        for item in meal.items.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            guard products[item.productId] != nil else {
                errorMessage = "\(item.productName) finnes ikke lenger lokalt. Fjern varen fra måltidet før du logger."
                return false
            }
            guard let amount = amounts[item.id], valid(amount: amount), valid(item: item) else {
                errorMessage = "Alle mengder må være større enn 0 og høyst 10 000 i oppgitt enhet."
                return false
            }
            guard let nutrition = NutritionCalculator.scaledSnapshot(
                calories: item.calories,
                protein: item.proteinG,
                carbs: item.carbsG,
                fat: item.fatG,
                from: item.amountG,
                to: amount
            ), nutrition.calories <= Float(Int32.max) else {
                errorMessage = "Kunne ikke beregne næringsinnholdet."
                return false
            }
            logs.append(FoodLog(
                userId: userId,
                productId: item.productId,
                mealType: mealType,
                amountG: amount,
                amountUnit: item.resolvedAmountUnit,
                portionSelection: item.portionSelection?.scaled(to: amount),
                loggedDate: targetDate,
                loggedTime: timestamp,
                calories: nutrition.calories,
                proteinG: nutrition.protein,
                carbsG: nutrition.carbs,
                fatG: nutrition.fat,
                createdAt: timestamp
            ))
        }

        isPreparingMutation = false
        isSaving = true
        let context = contextID
        defer { isSaving = false }
        do {
            try await foodLogRepository.saveLogs(logs)
            guard context == contextID, self.userId == userId else { return true }
            receipt = SavedMealReceipt(
                mealName: meal.name,
                mealType: mealType,
                logIDs: logs.map(\.id),
                userId: userId,
                date: targetDate
            )
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "Kunne ikke loggføre måltidet. Ingen varer ble lagt til."
            return false
        }
    }

    @discardableResult
    func undo() async -> Bool {
        guard !isSaving, !isPreparingMutation, let receipt, receipt.userId == userId else { return false }
        isSaving = true
        let context = contextID
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await foodLogRepository.deleteLogs(receipt.logIDs)
            guard context == contextID, userId == receipt.userId else { return true }
            self.receipt = nil
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "Kunne ikke angre måltidet. Prøv igjen."
            return false
        }
    }

    func dismissReceipt() {
        receipt = nil
    }

    private func save(_ meal: SavedMeal) async -> Bool {
        guard !isSaving, !isPreparingMutation, meal.userId == userId else { return false }
        isSaving = true
        let context = contextID
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await savedMealRepository.saveSavedMeal(meal)
            guard context == contextID, userId == meal.userId else { return true }
            if let index = meals.firstIndex(where: { $0.id == meal.id }) {
                meals[index] = meal
            } else {
                meals.insert(meal, at: 0)
            }
            meals.sort { $0.updatedAt > $1.updatedAt }
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "Kunne ikke lagre måltidet. Prøv igjen."
            return false
        }
    }

    private func normalizedName(_ value: String) -> String? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty || clean.count > 80 ? nil : clean
    }

    private func validMealType(_ value: String) -> Bool {
        ["frokost", "lunsj", "middag", "snacks"].contains(value)
    }

    private func valid(amount: Float) -> Bool {
        amount.isFinite && amount > 0 && amount <= 10_000
    }

    private func valid(log: FoodLog) -> Bool {
        valid(amount: log.amountG) && log.calories >= 0 &&
        [log.proteinG, log.carbsG, log.fatG].allSatisfy { $0.isFinite && $0 >= 0 }
    }

    private func valid(item: SavedMealItem) -> Bool {
        valid(amount: item.amountG) && item.calories >= 0 &&
        [item.proteinG, item.carbsG, item.fatG].allSatisfy { $0.isFinite && $0 >= 0 }
    }
}
