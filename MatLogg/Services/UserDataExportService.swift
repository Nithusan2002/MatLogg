import Foundation
import Combine

protocol ProfileDataExportRepository {
    func exportProfileRecords(ownerId: UUID) async throws -> [String: [Data]]
}

@MainActor
final class UserDataExportService: UserDataExporting {
    private let healthRepository: any HealthProfileRepository
    private let productRepository: any ProductRepository
    private let personalDetailsStore: any PersonalDetailsStore
    private let logRepository: any FoodLogRepository
    private let waterRepository: any WaterRepository
    private let savedMealRepository: any SavedMealRepository
    private let profileDataRepository: any ProfileDataExportRepository

    /// Best-effort recovery of our own abandoned exports after a process crash.
    /// Fresh files may still be open in a share sheet and must be preserved.
    nonisolated static func cleanupExpiredExports(in directory: URL, now: Date = Date()) {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]) else { return }
        for file in files where file.lastPathComponent.hasPrefix("matlogg-export-") && file.pathExtension == "json" {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) > 24 * 60 * 60 else { continue }
            try? manager.removeItem(at: file)
        }
    }

    func removeExport(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    init(logRepository: any FoodLogRepository, savedMealRepository: any SavedMealRepository, waterRepository: any WaterRepository, healthRepository: any HealthProfileRepository, productRepository: any ProductRepository, personalDetailsStore: any PersonalDetailsStore, profileDataRepository: any ProfileDataExportRepository) {
        Self.cleanupExpiredExports(in: FileManager.default.temporaryDirectory)
        self.profileDataRepository = profileDataRepository
        self.healthRepository = healthRepository
        self.productRepository = productRepository
        self.personalDetailsStore = personalDetailsStore
        self.waterRepository = waterRepository
        self.logRepository = logRepository
        self.savedMealRepository = savedMealRepository
    }

    func export(for user: User) async -> URL? {
        let logs = await logRepository.getAllLogs(userId: user.id)
        let savedMeals = await savedMealRepository.getSavedMeals(userId: user.id)
        let water: [WaterGlass]
        do { water = try await waterRepository.getWaterGlasses(userId: user.id) }
        catch { return nil }
        let goal = await healthRepository.latestGoal(userId: user.id)
        let weights = await healthRepository.getWeightEntries(userId: user.id)
        let favorites = await productRepository.getFavorites(userId: user.id, kind: nil)
        let details = personalDetailsStore.load(userId: user.id)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let goalJSON: Any
        let weightsJSON: Any
        let favoritesJSON: Any
        let detailsJSON: Any
        do {
            goalJSON = try JSONSerialization.jsonObject(with: encoder.encode(goal), options: [.fragmentsAllowed])
            weightsJSON = try JSONSerialization.jsonObject(with: encoder.encode(weights))
            favoritesJSON = try JSONSerialization.jsonObject(with: encoder.encode(favorites))
            detailsJSON = try JSONSerialization.jsonObject(with: encoder.encode(details))
        } catch { return nil }
        func portionJSON(_ portion: PortionSelection?) -> Any {
            guard let portion, let data = try? encoder.encode(portion),
                  let json = try? JSONSerialization.jsonObject(with: data) else { return NSNull() }
            return json
        }
        var payload: [String: Any] = [
            "daily_goal": goalJSON,
            "weight_entries": weightsJSON,
            "favorites": favoritesJSON,
            "personal_details": detailsJSON,
            "user_id": user.id.uuidString,
            "email": user.email,
            "exported_at": ISO8601DateFormatter().string(from: Date()),
            "water_glasses": water.map { ["id": $0.id.uuidString, "date": ISO8601DateFormatter().string(from: $0.date), "created_at": ISO8601DateFormatter().string(from: $0.createdAt)] },
            "logs": logs.map { log in
                [
                    "product_id": log.productId.uuidString,
                    "meal_type": log.mealType,
                    "amount": log.amountG,
                    "amount_unit": log.resolvedAmountUnit.rawValue,
                    "portion_selection": portionJSON(log.portionSelection),
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
                    "local_image_jpeg_base64": (meal.localImageData?.base64EncodedString() as Any?) ?? NSNull(),
                    "updated_at": ISO8601DateFormatter().string(from: meal.updatedAt),
                    "items": meal.items.map { item in
                        [
                            "id": item.id.uuidString,
                            "product_id": item.productId.uuidString,
                            "product_name": item.productName,
                            "amount": item.amountG,
                            "amount_unit": item.resolvedAmountUnit.rawValue,
                            "portion_selection": portionJSON(item.portionSelection),
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

        do {
            let records = try await profileDataRepository.exportProfileRecords(ownerId: user.id)
            for (category, rows) in records {
                payload[category] = try rows.map { try JSONSerialization.jsonObject(with: $0) }
            }
            payload["export_schema_version"] = 2
        } catch { return nil }

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return nil
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("matlogg-export-\(UUID().uuidString).json")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
        }
    }
}
