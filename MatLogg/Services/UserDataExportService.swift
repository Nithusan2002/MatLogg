import Foundation
import Combine

@MainActor
final class UserDataExportService: ObservableObject {
    private let logRepository: any FoodLogRepository

    init(logRepository: any FoodLogRepository) {
        self.logRepository = logRepository
    }

    func export(for user: User) async -> URL? {
        let logs = await logRepository.getAllLogs(userId: user.id)
        let payload: [String: Any] = [
            "user_id": user.id.uuidString,
            "email": user.email,
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "logs": logs.map { log in
                [
                    "product_id": log.productId.uuidString,
                    "meal_type": log.mealType,
                    "amount_g": log.amountG,
                    "logged_date": ISO8601DateFormatter().string(from: log.loggedDate),
                    "calories": log.calories,
                    "protein_g": log.proteinG,
                    "carbs_g": log.carbsG,
                    "fat_g": log.fatG
                ]
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
