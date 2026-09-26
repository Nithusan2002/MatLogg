import Foundation
import Combine

@MainActor
final class LogViewModel: ObservableObject {
    @Published private(set) var todaysSummary = DailySummary.empty(for: Date())
    @Published private(set) var selectedSummary: DailySummary?
    @Published private(set) var yesterdaySummary: DailySummary?
    @Published private(set) var selectedProductNames: [UUID: String] = [:]
    @Published private(set) var errorMessage: String?
    @Published private(set) var mutationRevision = 0

    private let repository: any FoodLogRepository
    private var activeSummaryRequestID = UUID()

    init(repository: any FoodLogRepository) {
        self.repository = repository
    }

    func loadTodaysSummary(userId: UUID) async {
        todaysSummary = await repository.getTodaysSummary(userId: userId)
    }

    func fetchSummary(userId: UUID, date: Date) async -> DailySummary {
        await repository.getSummary(userId: userId, date: date)
    }

    func productNames(for logs: [FoodLog]) async -> [UUID: String] {
        let products = await repository.getProducts(Set(logs.map(\.productId)))
        return products.mapValues(\.name)
    }

    func loadSelectedSummary(userId: UUID?, date: Date, calendar: Calendar = .current) async {
        let requestID = UUID()
        activeSummaryRequestID = requestID

        guard let userId else {
            selectedSummary = nil
            yesterdaySummary = nil
            selectedProductNames = [:]
            return
        }

        let selected = await repository.getSummary(userId: userId, date: date)
        let productNames = await productNames(for: selected.logs)
        let yesterday: DailySummary?
        if calendar.isDateInToday(date),
           let previousDate = calendar.date(byAdding: .day, value: -1, to: date) {
            yesterday = await repository.getSummary(userId: userId, date: previousDate)
        } else {
            yesterday = nil
        }

        guard activeSummaryRequestID == requestID else { return }
        selectedSummary = selected
        yesterdaySummary = yesterday
        selectedProductNames = productNames
    }

    @discardableResult
    func logFood(
        product: Product,
        amountG: Float,
        mealType: String,
        userId: UUID,
        date: Date = Date()
    ) async -> Bool {
        let nutrition = product.calculateNutrition(forAmount: amountG)
        let log = FoodLog(
            userId: userId,
            productId: product.id,
            mealType: mealType,
            amountG: amountG,
            amountUnit: product.amountUnit,
            loggedDate: Calendar.current.startOfDay(for: date),
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
        date: Date = Date()
    ) async -> Bool {
        let logs = await repository.getAllLogs(userId: userId)
        let day = Calendar.current.startOfDay(for: date)
        let latest = logs
            .filter {
                $0.productId == productId &&
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
    func updateLog(_ log: FoodLog, amountG: Float, mealType: String, userId: UUID) async -> Bool {
        guard log.userId == userId else {
            errorMessage = "Kunne ikke oppdatere logging: Loggen tilhører en annen bruker"
            return false
        }
        guard let product = repository.getProduct(log.productId) else {
            errorMessage = "Kunne ikke oppdatere logging: Produktet finnes ikke lokalt"
            return false
        }

        let nutrition = product.calculateNutrition(forAmount: amountG)
        let updated = FoodLog(
            id: log.id,
            userId: log.userId,
            productId: log.productId,
            mealType: mealType,
            amountG: amountG,
            amountUnit: log.resolvedAmountUnit,
            loggedDate: log.loggedDate,
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
        let sourceSummary = await repository.getSummary(userId: userId, date: sourceDate)
        let targetDay = Calendar.current.startOfDay(for: targetDate)

        return await persist(errorPrefix: "Kunne ikke kopiere logging") {
            for log in sourceSummary.logs {
                let copy = FoodLog(
                    userId: userId,
                    productId: log.productId,
                    mealType: log.mealType,
                    amountG: log.amountG,
                    amountUnit: log.resolvedAmountUnit,
                    loggedDate: targetDay,
                    loggedTime: Date(),
                    calories: log.calories,
                    proteinG: log.proteinG,
                    carbsG: log.carbsG,
                    fatG: log.fatG
                )
                try await repository.saveLog(copy)
            }
        }
    }

    private func persist(
        errorPrefix: String,
        operation: () async throws -> Void
    ) async -> Bool {
        errorMessage = nil
        do {
            try await operation()
            mutationRevision += 1
            return true
        } catch {
            errorMessage = "\(errorPrefix): \(error.localizedDescription)"
            return false
        }
    }
}

private extension DailySummary {
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
