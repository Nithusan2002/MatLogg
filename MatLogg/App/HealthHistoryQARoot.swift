#if DEBUG
import SwiftUI

/// Disposable UI fixture: no normal app database and no native HealthKit access.
struct HealthHistoryQARoot: View {
    @StateObject private var integration: HealthIntegrationViewModel
    private let startupError: String?

    init() {
        let owner = UUID()
        do {
            let store = try LocalStore(databaseURL: FileManager.default.temporaryDirectory.appendingPathComponent("health-history-\(UUID()).sqlite"), healthWritesEnabled: true)
            let day = Calendar.current.startOfDay(for: Date())
            try store.saveLogs([FoodLog(userId: owner, productId: UUID(), mealType: "frokost", amountG: 100,
                loggedDate: day, calories: 120, proteinG: 4, carbsG: 8, fatG: 3)])
            try store.saveWeightEntry(WeightEntry(userId: owner, date: day, weightKg: 72))
            var settings = HealthIntegrationSettings()
            settings.shareNutrition = true
            settings.shareWeight = true
            settings.connectionID = UUID()
            try store.setHealthSettings(settings, owner: owner)
            let repo = DefaultHealthIntegrationRepository(store: LocalHealthExportStorage(store: store), client: HistoryQAClient(), enabled: { true })
            let model = HealthIntegrationViewModel(repository: repo)
            model.selectOwner(owner)
            _integration = StateObject(wrappedValue: model)
            startupError = nil
        } catch {
            _integration = StateObject(wrappedValue: HealthIntegrationViewModel(repository:
                DefaultHealthIntegrationRepository(store: nil, client: HistoryQAClient(), enabled: { false })))
            startupError = "Kunne ikke starte historikktest."
        }
    }
    var body: some View {
        NavigationStack {
            if let startupError { Text(startupError) }
            else { HealthExportSettingsView() }
        }
        .environmentObject(integration)
    }
}

@MainActor
private final class HistoryQAClient: HealthKitClient {
    var isAvailable: Bool { true }
    func requestAccess(settings: HealthIntegrationSettings) async throws {}
    func canWrite(_ kind: HealthDataKind) -> Bool { true }
    func save(_ record: HealthExportRecord) async throws {}
    func delete(_ record: HealthExportRecord) async throws {}
}
#endif
