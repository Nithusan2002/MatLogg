import Foundation
import Combine

@MainActor
final class UserDataExportService: ObservableObject {
    private let logRepository: any FoodLogRepository
    private let savedMealRepository: any SavedMealRepository

    init(logRepository: any FoodLogRepository, savedMealRepository: any SavedMealRepository) {
        self.logRepository = logRepository
        self.savedMealRepository = savedMealRepository
    }

    func export(for user: User) async -> URL? {
        let logs = await logRepository.getAllLogs(userId: user.id)
        let savedMeals = await savedMealRepository.getSavedMeals(userId: user.id)
        let payload: [String: Any] = [
            "user_id": user.id.uuidString,
            "email": user.email,
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "logs": logs.map { log in
                [
                    "product_id": log.productId.uuidString,
                    "meal_type": log.mealType,
                    "amount": log.amountG,
                    "amount_unit": log.resolvedAmountUnit.rawValue,
                    "amount_g": log.resolvedAmountUnit == .grams ? log.amountG as Any : NSNull() as Any,
                    "logged_date": ISO8601DateFormatter().string(from: log.loggedDate),
                    "calories": log.calories,
                    "protein_g": log.proteinG,
                    "carbs_g": log.carbsG,
                    "fat_g": log.fatG
                ]
            },
            "saved_meals": savedMeals.map { meal in
                [
                    "id": meal.id.uuidString,
                    "name": meal.name,
                    "suggested_meal_type": (meal.suggestedMealType as Any?) ?? NSNull(),
                    "updated_at": ISO8601DateFormatter().string(from: meal.updatedAt),
                    "items": meal.items.map { item in
                        [
                            "id": item.id.uuidString,
                            "product_id": item.productId.uuidString,
                            "product_name": item.productName,
                            "amount": item.amountG,
                            "amount_unit": item.resolvedAmountUnit.rawValue,
                            "amount_g": item.resolvedAmountUnit == .grams ? item.amountG as Any : NSNull() as Any,
                            "calories": item.calories,
                            "protein_g": item.proteinG,
                            "carbs_g": item.carbsG,
                            "fat_g": item.fatG,
                            "nutrition_source": item.nutritionSource.rawValue,
                            "sort_index": item.sortIndex
                        ] as [String: Any]
                    }
                ] as [String: Any]
            }
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("matlogg-export.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
