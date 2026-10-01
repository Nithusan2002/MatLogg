import Foundation
import Combine

/// Publishes a new app context only after its database is ready.
@MainActor
final class DemoMode: ObservableObject {
    @Published private(set) var isDemo = false
    @Published private(set) var revision = UUID()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    private(set) var database = DatabaseService()
    private(set) var defaults = UserDefaults.standard
    private let selectionDefaults: UserDefaults
    private let demoDefaults: UserDefaults?
    private let directory: URL
    private let loadCatalog: () async throws -> [MatvaretabellenProduct]

    init(selectionDefaults: UserDefaults = .standard, demoDefaults: UserDefaults?, directory: URL, loadCatalog: @escaping () async throws -> [MatvaretabellenProduct] = { try await MatvaretabellenService().fetchCommonFoods() }) {
        self.selectionDefaults = selectionDefaults
        self.demoDefaults = demoDefaults
        self.directory = directory
        self.loadCatalog = loadCatalog
    }

    func restore() async {
        #if DEBUG
        if selectionDefaults.bool(forKey: "demoModeActive") { await selectDemo(true) }
        #endif
    }

    func selectDemo(_ enabled: Bool, reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if enabled {
                guard let demoDefaults else { throw CocoaError(.fileWriteUnknown) }
                let catalog = try await loadCatalog()
                try Task.checkCancellation()
                let user = AuthService(defaults: demoDefaults).activateLocalProfile()
                let url = directory.appendingPathComponent("demo-v1.sqlite")
                let products = catalog.map { FoodSearchCatalog.product($0) }
                let store = try await DemoDataset.prepare(at: url, userId: user.id, products: products, reset: reset)
                try Task.checkCancellation()
                if reset {
                    for key in demoDefaults.dictionaryRepresentation().keys where !key.hasPrefix("ml_") {
                        demoDefaults.removeObject(forKey: key)
                    }
                }
                AuthService(defaults: demoDefaults).setOnboardingCompleted(true, userId: user.id)
                database = DatabaseService(store: store, defaults: demoDefaults)
                defaults = demoDefaults
            } else {
                database = DatabaseService()
                defaults = .standard
            }
            isDemo = enabled
            selectionDefaults.set(enabled, forKey: "demoModeActive")
            revision = UUID()
        } catch {
            errorMessage = "Kunne ikke åpne demodata. \(error.localizedDescription)"
        }
    }
}

struct DemoDataset {
    /// Staging ensures interrupted or failed seeding never exposes a partial dataset.
    static func prepare(at url: URL, userId: UUID, products: [Product], reset: Bool = false, now: Date = Date()) async throws -> LocalStore {
        let files = FileManager.default
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !reset && files.fileExists(atPath: url.path) { return try LocalStore(databaseURL: url) }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? files.removeItem(at: temporary) }
        try await seed(at: temporary, userId: userId, products: products, now: now)
        if files.fileExists(atPath: url.path) {
            _ = try files.replaceItemAt(url, withItemAt: temporary)
        } else {
            try files.moveItem(at: temporary, to: url)
        }
        return try LocalStore(databaseURL: url)
    }

    private static func seed(at url: URL, userId: UUID, products: [Product], now: Date) async throws {
        guard !products.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let store = try LocalStore(databaseURL: url)
        let preferredIDs = ["05.003", "06.525", "05.342", "02.026", "04.342", "05.337", "03.418", "01.299", "06.620", "06.747", "06.718", "06.107"]
        let preferred = preferredIDs.compactMap { id in products.first { $0.externalID == id } }
        let chosen = preferred.isEmpty ? Array(products.prefix(12)) : preferred
        for product in chosen { try store.cacheCatalogProduct(product) }
        try store.saveGoal(Goal(userId: userId, goalType: "maintain", dailyCalories: 2200, proteinTargetG: 110, carbsTargetG: 275, fatTargetG: 73))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for offset in 0..<56 {
            try Task.checkCancellation()
            await Task.yield()
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if offset % 13 == 5 { continue }
            let count = offset % 9 == 4 ? 2 : 9 + offset % 3
            var logs: [FoodLog] = []
            for index in 0..<count {
                let menu = [0, 1, 2, 3, offset % 2 == 0 ? 4 : 6, 5, 9, 7, 8, 11, 10]
                let product = chosen[menu[index % menu.count] % chosen.count]
                let amount = Float(60 + (offset + index * 7) % 180)
                let scale = amount / 100
                logs.append(FoodLog(userId: userId, productId: product.id, mealType: index < 2 ? "frokost" : index < 4 ? "lunsj" : index < 7 ? "middag" : "snacks", amountG: amount, loggedDate: day, loggedTime: day.addingTimeInterval(Double(8 + index) * 3600), calories: product.caloriesPer100g * scale, proteinG: product.proteinGPer100g * scale, carbsG: product.carbsGPer100g * scale, fatG: product.fatGPer100g * scale))
            }
            try store.saveLogs(logs)
            for index in 0..<(3 + offset % 5) {
                try store.saveWaterGlass(WaterGlass(userId: userId, date: day.addingTimeInterval(Double(9 + index) * 3600)))
            }
            if offset % 3 == 0 {
                try store.saveWeightEntry(WeightEntry(userId: userId, date: day, weightKg: 74 + Double(offset % 7) * 0.1))
            }
        }
        for product in chosen.prefix(6) { try store.toggleFavorite(userId: userId, productId: product.id) }
        for index in 0..<4 {
            let product = chosen[[0, 2, 4, 7][index] % chosen.count]
            try store.saveSavedMeal(SavedMeal(userId: userId, name: ["Enkel frokost", "Rask lunsj", "Hverdagsmiddag", "Lite mellommåltid"][index], suggestedMealType: ["frokost", "lunsj", "middag", "snacks"][index], items: [SavedMealItem(productId: product.id, productName: product.name, amountG: 100, calories: product.caloriesPer100g, proteinG: product.proteinGPer100g, carbsG: product.carbsGPer100g, fatG: product.fatGPer100g, nutritionSource: product.nutritionSource, sortIndex: 0)]))
        }
    }
}

