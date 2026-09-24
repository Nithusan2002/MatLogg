import Foundation
import Combine

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
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var receipt: SavedMealReceipt?
    @Published private(set) var mutationRevision = 0

    private let savedMealRepository: any SavedMealRepository
    private let foodLogRepository: any FoodLogRepository
    private let calendar: Calendar
    private let now: () -> Date
    private var userId: UUID?
    private var contextID = UUID()

    init(
        savedMealRepository: any SavedMealRepository,
        foodLogRepository: any FoodLogRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.savedMealRepository = savedMealRepository
        self.foodLogRepository = foodLogRepository
        self.calendar = calendar
        self.now = now
    }

    func reset() {
        contextID = UUID()
        userId = nil
        meals = []
        receipt = nil
        errorMessage = nil
    }

    func load(userId: UUID) async {
        if self.userId != userId {
            contextID = UUID()
            meals = []
            receipt = nil
            errorMessage = nil
        }
        let context = contextID
        self.userId = userId
        let loaded = await savedMealRepository.getSavedMeals(userId: userId)
        guard context == contextID, self.userId == userId else { return }
        meals = loaded
    }

    @discardableResult
    func saveFromLogs(name: String, mealType: String, logs: [FoodLog], userId: UUID) async -> Bool {
        guard !isSaving else { return false }
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

        var items: [SavedMealItem] = []
        for (index, log) in logs.sorted(by: { $0.loggedTime < $1.loggedTime }).enumerated() {
            guard valid(log: log), let product = foodLogRepository.getProduct(log.productId) else {
                errorMessage = "En av matvarene mangler lokalt produktgrunnlag og kan ikke lagres i måltidet."
                return false
            }
            items.append(SavedMealItem(
                productId: log.productId,
                productName: product.name,
                amountG: log.amountG,
                calories: log.calories,
                proteinG: log.proteinG,
                carbsG: log.carbsG,
                fatG: log.fatG,
                nutritionSource: product.nutritionSource,
                sortIndex: index
            ))
        }

        return await save(SavedMeal(
            userId: userId,
            name: cleanName,
            suggestedMealType: mealType,
            items: items
        ))
    }

    @discardableResult
    func update(_ meal: SavedMeal, name: String, amounts: [UUID: Float], removedItemIDs: Set<UUID>) async -> Bool {
        guard meal.userId == userId else {
            errorMessage = "Måltidet tilhører en annen bruker."
            return false
        }
        guard let cleanName = normalizedName(name) else {
            errorMessage = "Gi det lagrede måltidet et navn på opptil 80 tegn."
            return false
        }
        let kept = meal.items.filter { !removedItemIDs.contains($0.id) }
        guard !kept.isEmpty else {
            errorMessage = "Et lagret måltid må inneholde minst én matvare."
            return false
        }

        var updatedItems: [SavedMealItem] = []
        for (index, original) in kept.sorted(by: { $0.sortIndex < $1.sortIndex }).enumerated() {
            guard let amount = amounts[original.id], valid(amount: amount) else {
                errorMessage = "Alle mengder må være større enn 0 og høyst 10 000 g."
                return false
            }
            let factor = amount / original.amountG
            guard factor.isFinite else { return false }
            var item = original
            item.amountG = amount
            item.calories = Int((Double(original.calories) * Double(factor)).rounded())
            item.proteinG = original.proteinG * factor
            item.carbsG = original.carbsG * factor
            item.fatG = original.fatG * factor
            item.sortIndex = index
            updatedItems.append(item)
        }

        var updated = meal
        updated.name = cleanName
        updated.items = updatedItems
        updated.updatedAt = now()
        return await save(updated)
    }

    @discardableResult
    func delete(_ meal: SavedMeal) async -> Bool {
        guard !isSaving, meal.userId == userId else { return false }
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
        guard !isSaving, meal.userId == userId, self.userId == userId,
              validMealType(mealType), !meal.items.isEmpty else { return false }
        errorMessage = nil

        let timestamp = now()
        let targetDate = calendar.startOfDay(for: date)
        var logs: [FoodLog] = []
        for item in meal.items.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            guard foodLogRepository.getProduct(item.productId) != nil else {
                errorMessage = "\(item.productName) finnes ikke lenger lokalt. Fjern varen fra måltidet før du logger."
                return false
            }
            guard let amount = amounts[item.id], valid(amount: amount), valid(item: item) else {
                errorMessage = "Alle mengder må være større enn 0 og høyst 10 000 g."
                return false
            }
            let factor = amount / item.amountG
            let calories = Double(item.calories) * Double(factor)
            let macros = [item.proteinG, item.carbsG, item.fatG].map { $0 * factor }
            guard calories.isFinite, calories >= 0, calories.rounded() <= Double(Int32.max),
                  macros.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
                errorMessage = "Næringsgrunnlaget kunne ikke beregnes."
                return false
            }
            logs.append(FoodLog(
                userId: userId,
                productId: item.productId,
                mealType: mealType,
                amountG: amount,
                loggedDate: targetDate,
                loggedTime: timestamp,
                calories: Int(calories.rounded()),
                proteinG: macros[0],
                carbsG: macros[1],
                fatG: macros[2],
                createdAt: timestamp
            ))
        }

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
        guard !isSaving, let receipt, receipt.userId == userId else { return false }
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
        guard !isSaving, meal.userId == userId else { return false }
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
