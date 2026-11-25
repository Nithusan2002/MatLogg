import Foundation
import Combine

struct SelectedDayPresentation {
    let summary: DailySummary?
    let productNames: [UUID: String]
    static let empty = SelectedDayPresentation(summary: nil, productNames: [:])
}

struct DayCopyReceipt: Identifiable {
    let id = UUID()
    let userId: UUID
    let logIDs: [UUID]
}

@MainActor
final class LogViewModel: ObservableObject {
    @Published private(set) var todaysSummary = DailySummary.empty(for: Date())
    @Published private(set) var summaryErrorMessage: String?
    @Published private(set) var isSummaryLoading = true
    @Published private(set) var selectedDay = SelectedDayPresentation.empty
    @Published private(set) var selectedSummary: DailySummary?
    @Published private(set) var yesterdaySummary: DailySummary?
    @Published private(set) var selectedProductNames: [UUID: String] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var mutationRevision = 0

    /// Repositories used by other logging features have already committed the write.
    func didPersistExternalLog() {
        mutationRevision += 1
    }

    @Published private(set) var copyReceipt: DayCopyReceipt?
    @Published private(set) var isCopyingOrUndoing = false
    private var copyContextRevision = 0

    func dismissCopyReceipt(id: UUID? = nil) {
        guard id == nil || copyReceipt?.id == id else { return }
        copyContextRevision += 1
        copyReceipt = nil
    }

    @Published private(set) var deletionReceiptID: UUID?
    @Published private(set) var deletedLogCount = 0
    @Published private(set) var isDeletingOrRestoring = false
    private var deletedLogs: [FoodLog] = []
    private var deletionContextRevision = 0

    func dismissDeletionReceipt() {
        deletionContextRevision += 1
        deletedLogs = []
        deletedLogCount = 0
        deletionReceiptID = nil
    }

    @discardableResult
    func deleteWithUndo(_ log: FoodLog, userId: UUID) async -> Bool {
        guard !isDeletingOrRestoring else { return false }
        guard !deletedLogs.contains(where: { $0.id == log.id }) else { return false }
        let contextRevision = deletionContextRevision
        isDeletingOrRestoring = true
        defer { isDeletingOrRestoring = false }
        guard await deleteLog(log, userId: userId) else { return false }
        guard contextRevision == deletionContextRevision else { return true }
        if deletedLogs.first?.userId != userId { deletedLogs = [] }
        deletedLogs.append(log)
        deletedLogCount = deletedLogs.count
        deletionReceiptID = UUID()
        return true
    }

    /// A multi-selection is one receipt, independent of earlier single deletions.
    @discardableResult
    func deleteBatchWithUndo(_ logs: [FoodLog], userId: UUID) async -> Bool {
        guard !isDeletingOrRestoring, !logs.isEmpty else { return false }
        guard logs.allSatisfy({ $0.userId == userId }), Set(logs.map(\.id)).count == logs.count else {
            errorMessage = "Kunne ikke slette registreringene: Ugyldig utvalg."
            return false
        }
        let contextRevision = deletionContextRevision
        isDeletingOrRestoring = true
        defer { isDeletingOrRestoring = false }
        let success = await persist(errorPrefix: "Kunne ikke slette registreringene") {
            try await repository.deleteLogs(logs.map(\.id))
        }
        guard success else { return false }
        guard contextRevision == deletionContextRevision else { return true }
        deletedLogs = logs
        deletedLogCount = logs.count
        deletionReceiptID = UUID()
        return true
    }

    @discardableResult
    func undoDeletion(userId: UUID) async -> Bool {
        guard !isDeletingOrRestoring, !deletedLogs.isEmpty else { return false }
        guard deletedLogs.allSatisfy({ $0.userId == userId }) else {
            errorMessage = "Kunne ikke angre sletting: Loggen tilhører en annen bruker"
            return false
        }
        let contextRevision = deletionContextRevision
        isDeletingOrRestoring = true
        // Fresh IDs prevent a delayed delete retry from deleting restored entries.
        let restored = deletedLogs.map { log in
            FoodLog(userId: log.userId, productId: log.productId, mealType: log.mealType,
                    amountG: log.amountG, amountUnit: log.resolvedAmountUnit, portionSelection: log.portionSelection,
                    nutritionPreparation: log.nutritionPreparation, nutritionSource: log.nutritionSource, loggedDate: log.loggedDate, loggedTime: log.loggedTime,
                    calories: log.calories, proteinG: log.proteinG,
                    carbsG: log.carbsG, fatG: log.fatG, createdAt: log.createdAt)
        }
        let success = await persist(errorPrefix: "Kunne ikke angre sletting") {
            try await repository.saveLogs(restored)
        }
        isDeletingOrRestoring = false
        if contextRevision == deletionContextRevision {
            if success { dismissDeletionReceipt() }
            else { deletionReceiptID = UUID() }
        }
        return success
    }

    private let repository: any FoodLogRepository
    private var activeSummaryRequestID = UUID()
    private var summaryUserID: UUID?
    private var summaryDate: Date?

    func resetSelectedSummary() {
        dismissCopyReceipt()
        activeSummaryRequestID = UUID()
        summaryUserID = nil
        summaryDate = nil
        selectedDay = .empty
        selectedSummary = nil
        yesterdaySummary = nil
        selectedProductNames = [:]
        mealProductBrands = [:]
        mealProductImageURLs = [:]
        mealProductImageData = [:]
        mealProductFoodGroups = [:]
        isSummaryLoading = true
        summaryErrorMessage = nil
    }

    init(repository: any FoodLogRepository) {
        self.repository = repository
    }

    private var todayRequestID = UUID()

    func loadTodaysSummary(userId: UUID) async {
        let requestID = UUID()
        todayRequestID = requestID
        let summary: DailySummary
        do {
            guard let loaded = try await repository.loadSummaries(userId: userId, dates: [Date()]).first else {
                throw DatabaseServiceError.unavailable
            }
            summary = loaded
        } catch {
            guard todayRequestID == requestID, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke hente dagsoversikten. Prøv igjen."
            return
        }
        guard todayRequestID == requestID, !Task.isCancelled else { return }
        todaysSummary = summary
    }

    func fetchSummary(userId: UUID, date: Date) async throws -> DailySummary {
        guard let summary = try await repository.loadSummaries(userId: userId, dates: [date]).first else {
            throw DatabaseServiceError.unavailable
        }
        return summary
    }

    @Published private(set) var mealProductBrands: [UUID: String] = [:]
    @Published private(set) var mealProductImageURLs: [UUID: URL] = [:]
    @Published private(set) var mealProductImageData: [UUID: Data] = [:]
    @Published private(set) var mealProductFoodGroups: [UUID: FoodGroup] = [:]
    private var imageProductsRequestID = UUID()

    func loadMealProductImages(for logs: [FoodLog]) async {
        let requestID = UUID()
        imageProductsRequestID = requestID
        mealProductBrands = [:]
        mealProductImageURLs = [:]
        mealProductImageData = [:]
        mealProductFoodGroups = [:]
        let products = await repository.getProducts(Set(logs.map(\.productId)))
        guard imageProductsRequestID == requestID else { return }
        mealProductBrands = products.compactMapValues(\.brand)
        mealProductImageData = products.compactMapValues(\.localImageData)
        mealProductFoodGroups = products.mapValues(\.foodGroup)
        mealProductImageURLs = products.compactMapValues { product in
            product.imageUrl.flatMap(URL.init(string:))
        }
    }

    func productNames(for logs: [FoodLog]) async -> [UUID: String] {
        let products = await repository.getProducts(Set(logs.map(\.productId)))
        return products.mapValues(\.name)
    }

    func loadSelectedSummary(userId: UUID?, date: Date, calendar: Calendar = .current) async {
        let day = calendar.startOfDay(for: date)
        if summaryUserID != userId || summaryDate != day { resetSelectedSummary() }
        summaryUserID = userId
        summaryDate = day
        let requestID = UUID()
        activeSummaryRequestID = requestID
        isSummaryLoading = true
        summaryErrorMessage = nil
        defer {
            if activeSummaryRequestID == requestID { isSummaryLoading = false }
        }

        guard let userId else {
            selectedDay = .empty
            selectedSummary = nil
            yesterdaySummary = nil
            selectedProductNames = [:]
            mealProductBrands = [:]
            mealProductImageURLs = [:]
            mealProductImageData = [:]
            mealProductFoodGroups = [:]
            return
        }

        let previousDate = calendar.isDateInToday(date)
            ? calendar.date(byAdding: .day, value: -1, to: date) : nil
        let summaries: [DailySummary]
        do {
            summaries = try await repository.loadSummaries(userId: userId, dates: [date] + (previousDate.map { [$0] } ?? []))
        } catch {
            guard activeSummaryRequestID == requestID, !Task.isCancelled else { return }
            summaryErrorMessage = "Kunne ikke hente måltidene. Prøv igjen."
            return
        }
        guard let selected = summaries.first else {
            guard activeSummaryRequestID == requestID, !Task.isCancelled else { return }
            summaryErrorMessage = "Kunne ikke hente måltidene. Prøv igjen."
            return
        }
        let yesterday = previousDate == nil ? nil : summaries.dropFirst().first
        let products = await repository.getProducts(Set(selected.logs.map(\.productId)))

        guard activeSummaryRequestID == requestID, !Task.isCancelled else { return }
        selectedSummary = selected
        yesterdaySummary = yesterday
        selectedProductNames = products.mapValues(\.name)
        mealProductBrands = products.compactMapValues(\.brand)
        mealProductImageData = products.compactMapValues(\.localImageData)
        mealProductFoodGroups = products.mapValues(\.foodGroup)
        mealProductImageURLs = products.compactMapValues { $0.imageUrl.flatMap(URL.init(string:)) }
        selectedDay = SelectedDayPresentation(summary: selected, productNames: selectedProductNames)
    }

    func logs(for mealType: String?) -> [FoodLog] {
        let logs = selectedSummary?.logs ?? []
        guard let mealType else { return logs }
        return logs.filter { $0.mealType == mealType }
    }

    func nutrition(for mealType: String?) -> NutritionBreakdown {
        NutritionCalculator.totals(for: logs(for: mealType))
    }

    @discardableResult
    func logFood(
        product: Product,
        amountG: Float,
        mealType: String,
        userId: UUID,
        date: Date = Date(),
        portionSelection: PortionSelection? = nil
    ) async -> Bool {
        let timing = PerformanceSignposts.begin("Log.Food")
        defer { PerformanceSignposts.end(timing) }
        guard portionSelection == nil || portionSelection?.matches(amount: Double(amountG), unit: product.amountUnit) == true else {
            errorMessage = "Porsjonen samsvarer ikke med mengden."
            return false
        }
        guard let nutrition = NutritionCalculator.validatedCalculation(
            per100: NutritionBreakdown(
                calories: product.caloriesPer100g,
                protein: product.proteinGPer100g,
                carbs: product.carbsGPer100g,
                fat: product.fatGPer100g
            ),
            amount: amountG
        ) else {
            errorMessage = "Kunne ikke lagre: Sjekk mengden og næringstallene."
            return false
        }
        let log = FoodLog(
            userId: userId,
            productId: product.id,
            mealType: mealType,
            amountG: amountG,
            amountUnit: product.amountUnit,
            portionSelection: portionSelection,
            nutritionPreparation: product.nutritionPreparation, nutritionSource: product.nutritionSource, loggedDate: Calendar.current.startOfDay(for: date),
            loggedTime: date,
            calories: nutrition.calories,
            proteinG: nutrition.protein,
            carbsG: nutrition.carbs,
            fatG: nutrition.fat
        )

        return await persist(errorPrefix: "Kunne ikke lagre logging") {
            try await repository.saveLog(log)
        }
    }

    @discardableResult
    func deleteLog(_ log: FoodLog, userId: UUID) async -> Bool {
        guard log.userId == userId else {
            errorMessage = "Kunne ikke slette logging: Loggen tilhører en annen bruker"
            return false
        }
        return await persist(errorPrefix: "Kunne ikke slette logging") {
            try await repository.deleteLog(log.id)
        }
    }

    @discardableResult
    func undoLatestLog(
        productId: UUID,
        mealType: String,
        amountG: Float,
        userId: UUID,
        date: Date = Date(),
        logID: UUID? = nil
    ) async -> Bool {
        let logs: [FoodLog]
        do { logs = try await repository.loadAllLogs(userId: userId) }
        catch {
            errorMessage = "Kunne ikke angre logging. Prøv igjen."
            return false
        }
        let day = Calendar.current.startOfDay(for: date)
        let latest = logs
            .filter {
                (logID == nil || $0.id == logID) &&
                $0.userId == userId && $0.productId == productId &&
                $0.mealType == mealType &&
                $0.amountG == amountG &&
                Calendar.current.isDate($0.loggedDate, inSameDayAs: day)
            }
            .max(by: { $0.loggedTime < $1.loggedTime })

        guard let latest else { return false }
        return await persist(errorPrefix: "Kunne ikke angre logging") {
            try await repository.deleteLog(latest.id)
        }
    }

    @discardableResult
    func updateLog(_ log: FoodLog, amountG: Float, mealType: String, userId: UUID, portionSelection: PortionSelection? = nil, clearPortion: Bool = false) async -> Bool {
        guard log.userId == userId else {
            errorMessage = "Kunne ikke oppdatere logging: Loggen tilhører en annen bruker"
            return false
        }
        let portion = clearPortion ? nil : (portionSelection ?? log.portionSelection?.scaled(to: amountG))
        guard portion == nil || portion?.matches(amount: Double(amountG), unit: log.resolvedAmountUnit) == true else {
            errorMessage = "Porsjonen samsvarer ikke med mengden."
            return false
        }
        guard let nutrition = NutritionCalculator.scaledSnapshot(
            calories: log.calories,
            protein: log.proteinG,
            carbs: log.carbsG,
            fat: log.fatG,
            from: log.amountG,
            to: amountG
        ) else {
            errorMessage = "Kunne ikke lagre endringene: Sjekk næringstallene."
            return false
        }
        let updated = FoodLog(
            id: log.id,
            userId: log.userId,
            productId: log.productId,
            mealType: mealType,
            amountG: amountG,
            amountUnit: log.resolvedAmountUnit, portionSelection: portion,
            nutritionPreparation: log.nutritionPreparation, nutritionSource: log.nutritionSource, loggedDate: log.loggedDate,
            loggedTime: log.loggedTime,
            calories: nutrition.calories,
            proteinG: nutrition.protein,
            carbsG: nutrition.carbs,
            fatG: nutrition.fat,
            createdAt: log.createdAt,
            isSynced: log.isSynced
        )

        return await persist(errorPrefix: "Kunne ikke oppdatere logging") {
            try await repository.saveLog(updated)
        }
    }

    @discardableResult
    func copyLogs(from sourceDate: Date, to targetDate: Date, userId: UUID) async -> Bool {
        guard !isCopyingOrUndoing else { return false }
        isCopyingOrUndoing = true
        defer { isCopyingOrUndoing = false }
        dismissCopyReceipt()
        let context = copyContextRevision
        let sourceSummary: DailySummary
        do {
            guard let summary = try await repository.loadSummaries(userId: userId, dates: [sourceDate]).first else {
                throw DatabaseServiceError.unavailable
            }
            sourceSummary = summary
        } catch {
            guard context == copyContextRevision, !Task.isCancelled else { return false }
            errorMessage = "Kunne ikke hente registreringene som skal kopieres. Prøv igjen."
            return false
        }
        guard context == copyContextRevision, !Task.isCancelled else { return false }
        guard sourceSummary.logs.allSatisfy({ $0.userId == userId }) else {
            errorMessage = "Kunne ikke kopiere logging: Loggen tilhører en annen bruker."
            return false
        }
        guard !sourceSummary.logs.isEmpty else {
            errorMessage = "Ingen registreringer å kopiere."
            return false
        }
        let targetDay = Calendar.current.startOfDay(for: targetDate)
        let timestamp = Date()
        let copies = sourceSummary.logs.map { log in
            FoodLog(userId: userId, productId: log.productId, mealType: log.mealType,
                amountG: log.amountG, amountUnit: log.resolvedAmountUnit,
                portionSelection: log.portionSelection, nutritionPreparation: log.nutritionPreparation,
                nutritionSource: log.nutritionSource, loggedDate: targetDay, loggedTime: timestamp,
                calories: log.calories, proteinG: log.proteinG, carbsG: log.carbsG, fatG: log.fatG)
        }
        let success = await persist(errorPrefix: "Kunne ikke kopiere logging") {
            try await repository.saveLogs(copies)
        }
        if success, context == copyContextRevision {
            copyReceipt = DayCopyReceipt(userId: userId, logIDs: copies.map(\.id))
        }
        return success
    }

    @discardableResult
    func undoDayCopy(userId: UUID) async -> Bool {
        guard !isCopyingOrUndoing, let receipt = copyReceipt else { return false }
        guard receipt.userId == userId else {
            errorMessage = "Kunne ikke angre kopieringen: Loggen tilhører en annen bruker."
            return false
        }
        let context = copyContextRevision
        isCopyingOrUndoing = true
        defer { isCopyingOrUndoing = false }
        let success = await persist(errorPrefix: "Kunne ikke angre kopieringen") {
            try await repository.deleteLogs(receipt.logIDs)
        }
        if success, context == copyContextRevision { dismissCopyReceipt(id: receipt.id) }
        return success
    }

    private func persist(
        errorPrefix: String,
        operation: () async throws -> Void
    ) async -> Bool {
        let timing = PerformanceSignposts.begin("Log.Persist")
        defer { PerformanceSignposts.end(timing) }
        errorMessage = nil
        do {
            try await operation()
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "\(errorPrefix). Prøv igjen."
            return false
        }
    }
}

extension DailySummary {
    static func empty(for date: Date) -> DailySummary {
        DailySummary(
            date: date,
            totalCalories: 0,
            totalProtein: 0,
            totalCarbs: 0,
            totalFat: 0,
            logs: []
        )
    }
}
