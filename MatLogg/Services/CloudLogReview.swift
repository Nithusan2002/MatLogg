import Foundation

nonisolated enum CloudLogResolution: Sendable { case useCloud, useLocal }

/// A confirmation snapshot. Any intervening local/remote change invalidates it.
nonisolated struct CloudLogReview: Codable, Sendable, Identifiable {
    var id: UUID { entityId }
    let entityId: UUID
    let epoch: UUID
    let local: CloudLogAggregate?
    let server: CloudLogChange?
    let mutations: [CloudLogMutation]
    let domain: Data?
    let recovery: Data?

    func matches(_ other: CloudLogReview) throws -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self) == encoder.encode(other)
    }
}

nonisolated extension CloudLogAggregate {
    func copiedLog(id: UUID) throws -> CloudLogAggregate {
        let value = FoodLog(id: id, userId: log.userId, productId: log.productId, mealType: log.mealType,
            amountG: log.amountG, amountUnit: log.resolvedAmountUnit, portionSelection: log.portionSelection,
            nutritionPreparation: log.nutritionPreparation, nutritionSource: log.nutritionSource,
            loggedDate: log.loggedDate, loggedTime: log.loggedTime, calories: log.calories,
            proteinG: log.proteinG, carbsG: log.carbsG, fatG: log.fatG, createdAt: log.createdAt, isSynced: false)
        return try CloudLogAggregate(log: value, product: product)
    }
}
