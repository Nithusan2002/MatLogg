import Foundation
import Combine

struct MealReuseItem: Identifiable {
    let original: FoodLog
    let product: Product
    var amountText: String
    var id: UUID { original.id }
    var name: String { product.name }
    var source: String { product.nutritionSource.rawValue }

    var amountG: Float? {
        let normalized = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Float(normalized), value.isFinite, value > 0, value <= 10_000 else { return nil }
        return value
    }
}

struct MealReuseSuggestion: Identifiable {
    let mealType: String
    var items: [MealReuseItem]
    fileprivate let contextID: UUID
    var id: String { mealType }
    var title: String {
        switch mealType {
        case "frokost": return "Frokosten fra i går?"
        case "lunsj": return "Lunsjen fra i går?"
        case "middag": return "Middagen fra i går?"
        default: return "Kveldsmaten fra i går?"
        }
    }
}

struct MealReuseReceipt {
    let mealType: String
    let logIDs: [UUID]
    let userId: UUID
    let date: Date
    var title: String {
        switch mealType {
        case "frokost": return "Frokost"
        case "lunsj": return "Lunsj"
        case "middag": return "Middag"
        default: return "Kveldsmat"
        }
    }
}

@MainActor
final class MealReuseViewModel: ObservableObject {
    @Published private(set) var suggestions: [MealReuseSuggestion] = []
    @Published private(set) var draft: MealReuseSuggestion?
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var receipt: MealReuseReceipt?

    private let repository: any FoodLogRepository
    private let calendar: Calendar
    private let now: () -> Date
    private var userId: UUID?
    private var day: Date?
    private var contextID = UUID()
    private var loadID = UUID()
    private var dismissed: Set<String> = []

    init(repository: any FoodLogRepository, calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    var isDraftValid: Bool {
        guard let draft else { return false }
        return !draft.items.isEmpty && draft.items.allSatisfy { $0.amountG != nil }
    }

    /// Invalidate in-flight reads and remove account data synchronously at logout.
    func reset() {
        contextID = UUID()
        loadID = UUID()
        userId = nil
        day = nil
        suggestions = []
        draft = nil
        receipt = nil
        errorMessage = nil
        dismissed = []
        // A write already in progress retains its lock until its completion.
    }

    func load(userId: UUID, date: Date? = nil) async {
        let targetDay = calendar.startOfDay(for: date ?? now())
        if self.userId != userId || day != targetDay {
            contextID = UUID()
            self.userId = userId
            day = targetDay
            dismissed = []
            suggestions = []
            draft = nil
            receipt = nil
            errorMessage = nil
        }
        let requestID = UUID()
        loadID = requestID
        let context = contextID
        let logs = await repository.getAllLogs(userId: userId)
        guard loadID == requestID, contextID == context,
              calendar.isDate(targetDay, inSameDayAs: now()),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: targetDay) else { return }
        let ownLogs = logs.filter { $0.userId == userId }
        suggestions = ["frokost", "lunsj", "middag", "snacks"].compactMap { meal in
            guard !dismissed.contains(meal), !ownLogs.contains(where: {
                $0.mealType == meal && calendar.isDate($0.loggedDate, inSameDayAs: targetDay)
            }) else { return nil }
            let previous = ownLogs.filter {
                $0.mealType == meal && calendar.isDate($0.loggedDate, inSameDayAs: yesterday)
            }.sorted { $0.loggedTime < $1.loggedTime }
            guard !previous.isEmpty else { return nil }
            var items: [MealReuseItem] = []
            for log in previous {
                guard log.amountG.isFinite, log.amountG > 0, log.amountG <= 10_000,
                      log.calories >= 0, log.calories <= Int(Int32.max),
                      [log.proteinG, log.carbsG, log.fatG].allSatisfy({ $0.isFinite && $0 >= 0 }),
                      let product = repository.getProduct(log.productId) else { return nil }
                items.append(MealReuseItem(original: log, product: product,
                                           amountText: String(log.amountG).replacingOccurrences(of: ".", with: ",")))
            }
            return MealReuseSuggestion(mealType: meal, items: items, contextID: context)
        }
    }

    func dismissSuggestion(mealType: String) {
        guard !isSaving else { return }
        dismissed.insert(mealType)
        suggestions.removeAll { $0.mealType == mealType }
        if draft?.mealType == mealType { draft = nil }
    }

    func edit(_ suggestion: MealReuseSuggestion) {
        guard !isSaving, suggestion.contextID == contextID,
              let day, calendar.isDate(day, inSameDayAs: now()),
              suggestions.contains(where: { $0.mealType == suggestion.mealType }) else { return }
        errorMessage = nil
        draft = suggestion
    }

    func setAmount(itemId: UUID, text: String) {
        guard !isSaving, let index = draft?.items.firstIndex(where: { $0.id == itemId }) else { return }
        draft?.items[index].amountText = text
    }

    func removeItem(id: UUID) {
        guard !isSaving else { return }
        draft?.items.removeAll { $0.id == id }
    }

    func cancelEditing() {
        guard !isSaving else { return }
        draft = nil
        errorMessage = nil
    }

    @discardableResult
    func logDraft() async -> Bool {
        guard let draft else { return false }
        return await log(draft)
    }

    @discardableResult
    func log(_ suggestion: MealReuseSuggestion) async -> Bool {
        guard !isSaving else { return false }
        errorMessage = nil
        guard let userId, let day, suggestion.contextID == contextID,
              calendar.isDate(day, inSameDayAs: now()),
              suggestions.contains(where: { $0.mealType == suggestion.mealType }),
              !suggestion.items.isEmpty,
              suggestion.items.allSatisfy({ $0.amountG != nil && $0.original.userId == userId }) else {
            errorMessage = "Forslaget må oppdateres, eller mengden må være mellom 0 og 10 000 g."
            return false
        }
        let context = contextID
        isSaving = true
        defer { isSaving = false }
        let existing = await repository.getAllLogs(userId: userId)
        guard context == contextID, calendar.isDate(day, inSameDayAs: now()) else { return false }
        guard !existing.contains(where: {
            $0.userId == userId && $0.mealType == suggestion.mealType && calendar.isDate($0.loggedDate, inSameDayAs: day)
        }) else {
            errorMessage = "Dette måltidet har allerede registreringer i dag."
            return false
        }
        let timestamp = now()
        var copies: [FoodLog] = []
        for item in suggestion.items {
            guard let amount = item.amountG else { return false }
            let original = item.original
            let factor = amount / original.amountG
            let calories = Double(original.calories) * Double(factor)
            let macros = [original.proteinG, original.carbsG, original.fatG].map { $0 * factor }
            guard calories.isFinite, calories.rounded() <= Double(Int32.max),
                  macros.allSatisfy({ $0.isFinite }) else {
                errorMessage = "Mengden kunne ikke beregnes. Prøv en annen mengde."
                return false
            }
            copies.append(FoodLog(userId: userId, productId: original.productId, mealType: suggestion.mealType,
                                  amountG: amount, loggedDate: day, loggedTime: timestamp,
                                  calories: amount == original.amountG ? original.calories : Int(calories.rounded()),
                                  proteinG: macros[0], carbsG: macros[1], fatG: macros[2], createdAt: timestamp))
        }
        do {
            try await repository.saveLogs(copies)
            guard context == contextID else { return true }
            receipt = MealReuseReceipt(mealType: suggestion.mealType, logIDs: copies.map(\.id), userId: userId, date: day)
            dismissed.insert(suggestion.mealType)
            suggestions.removeAll { $0.mealType == suggestion.mealType }
            draft = nil
            return true
        } catch {
            if context == contextID { errorMessage = "Kunne ikke lagre måltidet. Prøv igjen." }
            return false
        }
    }

    @discardableResult
    func undo() async -> Bool {
        guard !isSaving, let receipt, receipt.userId == userId, receipt.date == day,
              calendar.isDate(receipt.date, inSameDayAs: now()) else { return false }
        let context = contextID
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await repository.deleteLogs(receipt.logIDs)
            if context == contextID { self.receipt = nil }
            return true
        } catch {
            if context == contextID { errorMessage = "Kunne ikke angre måltidet. Prøv igjen." }
            return false
        }
    }
}
