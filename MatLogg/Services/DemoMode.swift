import Foundation
import Combine

/// Publishes a new app context only after its database is ready.
@MainActor
final class DemoMode: ObservableObject {
    @Published private(set) var isDemo = false
    @Published private(set) var revision = UUID()
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var isReady = false
    private(set) var database = DatabaseService(storeResult: .failure(DatabaseServiceError.unavailable))
    private(set) var defaults = UserDefaults.standard
    private let selectionDefaults: UserDefaults
    private let demoDefaults: UserDefaults?
    private let directory: URL
    private let loadCatalog: () async throws -> [Product]
    private let openDatabase: () async -> DatabaseService

    init(selectionDefaults: UserDefaults = .standard, demoDefaults: UserDefaults?, directory: URL, loadCatalog: @escaping () async throws -> [Product] = { try await DemoProductCatalog.load() }, openDatabase: @escaping () async -> DatabaseService = { await DatabaseService.open() }) {
        self.selectionDefaults = selectionDefaults
        self.demoDefaults = demoDefaults
        self.directory = directory
        self.loadCatalog = loadCatalog
        self.openDatabase = openDatabase
    }

    func restore() async {
        guard !isReady, !isLoading else { return }
        isLoading = true
        database = await openDatabase()
        guard !Task.isCancelled else { isLoading = false; return }
        isLoading = false
        #if DEBUG
        if selectionDefaults.bool(forKey: "demoModeActive") { await selectDemo(true) }
        #endif
        isReady = true
    }

    func selectDemo(_ enabled: Bool, reset: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if enabled {
                guard let demoDefaults else { throw CocoaError(.fileWriteUnknown) }
                let products = try await loadCatalog()
                try Task.checkCancellation()
                let user = AuthService(defaults: demoDefaults).activateLocalProfile()
                let url = directory.appendingPathComponent("demo-v2.sqlite")
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
                database = await openDatabase()
                defaults = .standard
            }
            isDemo = enabled
            selectionDefaults.set(enabled, forKey: "demoModeActive")
            revision = UUID()
        } catch {
            errorMessage = "Kunne ikke åpne demodata. Prøv igjen."
        }
    }
}

/// A fixed OFF snapshot makes presentation data and images available offline.
nonisolated enum DemoProductCatalog {
    private struct Entry: Decodable {
        let code: String
        let name: String
        let brand: String?
        let imageURL: String
        let calories: Float
        let protein: Float
        let carbs: Float
        let fat: Float
        let sugar: Float?
        let fiber: Float?
        let sodium: Float?
    }

    static func load(bundle: Bundle = .main) async throws -> [Product] {
        let staples = try await MatvaretabellenService(bundle: bundle).fetchCommonFoods()
        let selectedIDs: Set<String> = ["06.525", "06.502", "05.342", "06.010", "06.069", "04.342", "06.262", "06.725", "03.481", "05.337", "06.622", "05.381", "03.139", "06.736", "06.524"]
        let selected = staples.filter { selectedIDs.contains($0.id) }
        guard selected.count == selectedIDs.count else { throw CocoaError(.fileReadCorruptFile) }
        let packaged = try await BackgroundWork.run {
            guard let url = bundle.url(forResource: "demo-openfoodfacts", withExtension: "json") else {
                throw CocoaError(.fileReadNoSuchFile)
            }
            let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
            guard !entries.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return try entries.map { entry in
                guard let image = bundle.url(forResource: "demo-off-\(entry.code)", withExtension: "jpg") else {
                    throw CocoaError(.fileReadNoSuchFile)
                }
                return Product(
                    id: Product.catalogID(source: "openfoodfacts", externalID: entry.code),
                    name: entry.name, brand: entry.brand, barcodeEan: entry.code,
                    source: "openfoodfacts", caloriesPer100g: entry.calories,
                    proteinGPer100g: entry.protein, carbsGPer100g: entry.carbs,
                    fatGPer100g: entry.fat, sugarGPer100g: entry.sugar,
                    fiberGPer100g: entry.fiber,
                    sodiumMgPer100g: entry.sodium.map { Int(($0 * 1000).rounded()) },
                    localImageData: try Data(contentsOf: image), imageUrl: entry.imageURL,
                    nutritionSource: .openFoodFacts, imageSource: .openFoodFacts,
                    externalID: entry.code, nutritionBasis: .per100g
                )
            }
        }
        return packaged + selected.map { FoodSearchCatalog.product($0) }
    }
}

nonisolated struct DemoDataset {
    /// Staging ensures interrupted or failed seeding never exposes a partial dataset.
    static func prepare(at url: URL, userId: UUID, products: [Product], reset: Bool = false, now: Date = Date()) async throws -> LocalStore {
        return try await BackgroundWork.run {
            try prepareStore(at: url, userId: userId, products: products, reset: reset, now: now)
        }
    }

    private static func prepareStore(at url: URL, userId: UUID, products: [Product], reset: Bool, now: Date) throws -> LocalStore {
        let files = FileManager.default
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !reset && files.fileExists(atPath: url.path) { return try LocalStore(databaseURL: url) }
        let temporary = url.deletingLastPathComponent().appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? files.removeItem(at: temporary) }
        try seed(at: temporary, userId: userId, products: products, now: now)
        if files.fileExists(atPath: url.path) {
            _ = try files.replaceItemAt(url, withItemAt: temporary)
        } else {
            try files.moveItem(at: temporary, to: url)
        }
        return try LocalStore(databaseURL: url)
    }

    private static func seed(at url: URL, userId: UUID, products: [Product], now: Date) throws {
        guard !products.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let store = try LocalStore(databaseURL: url)
        let chosen = products
        let meals = try menu(products: products)
        for product in chosen { try store.cacheCatalogProduct(product) }
        try store.saveGoal(Goal(userId: userId, goalType: "maintain", dailyCalories: 2200, proteinTargetG: 110, carbsTargetG: 275, fatTargetG: 73))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for offset in 0..<56 {
            try Task.checkCancellation()
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if offset % 13 == 5 { continue }
            let weekday = calendar.component(.weekday, from: day)
            let breakfast = offset % 2 == 0 ? 0 : 1
            let lunch = offset % 3 == 0 ? 3 : 2
            let dinner = weekday == 6 ? 6 : offset % 2 == 0 ? 4 : 5
            let snack = offset % 2 == 0 ? 7 : 8
            var logs: [FoodLog] = []
            for (mealIndex, menuIndex) in [breakfast, lunch, dinner, snack].enumerated() {
                let meal = meals[menuIndex]
                let hour = [8, 12, 17, 20][mealIndex]
                let time = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
                for item in meal.items {
                    logs.append(FoodLog(userId: userId, productId: item.productId, mealType: meal.type,
                        amountG: item.amountG, loggedDate: day, loggedTime: time,
                        calories: item.calories, proteinG: item.proteinG, carbsG: item.carbsG, fatG: item.fatG))
                }
            }
            try store.saveLogs(logs)
            for index in 0..<(3 + offset % 5) {
                try store.saveWaterGlass(WaterGlass(userId: userId, date: day.addingTimeInterval(Double(9 + index) * 3600)))
            }
            if offset % 3 == 0 {
                try store.saveWeightEntry(WeightEntry(userId: userId, date: day, weightKg: 74 + Double(offset) * 0.008 + Double(offset % 5 - 2) * 0.08))
            }
        }
        let favoriteCodes: Set<String> = ["7044416013141", "7038010053368", "7039010016322", "7038010054471", "06.525", "05.342", "04.342", "03.481"]
        for product in chosen where favoriteCodes.contains(product.externalID ?? "") {
            try store.toggleFavorite(userId: userId, productId: product.id)
        }
        for (index, meal) in meals.prefix(8).enumerated() {
            let created = today.addingTimeInterval(-Double(index + 1) * 86400)
            try store.saveSavedMeal(SavedMeal(userId: userId, name: meal.name,
                suggestedMealType: meal.type, items: meal.items, createdAt: created, updatedAt: created))
        }
    }

    private struct Meal {
        let name: String
        let type: String
        let items: [SavedMealItem]
    }

    /// Amounts refer to the exact catalog food, including cooked rice, meat and potatoes.
    private static func menu(products: [Product]) throws -> [Meal] {
        func meal(_ name: String, _ type: String, _ ingredients: [(String, Float)]) throws -> Meal {
            let items = try ingredients.enumerated().map { index, ingredient in
                guard let product = products.first(where: { $0.externalID == ingredient.0 }) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                let amount = ingredient.1
                let scale = amount / 100
                return SavedMealItem(productId: product.id, productName: product.name, amountG: amount,
                    calories: product.caloriesPer100g * scale, proteinG: product.proteinGPer100g * scale,
                    carbsG: product.carbsGPer100g * scale, fatG: product.fatGPer100g * scale,
                    nutritionSource: product.nutritionSource, sortIndex: index)
            }
            return Meal(name: name, type: type, items: items)
        }
        return try [
            meal("Yoghurtbolle med havre og blåbær", "frokost", [("7038010045073", 200), ("7044416013141", 60), ("06.502", 75), ("06.525", 100)]),
            meal("Grovbrød med ost og agurk", "frokost", [("05.342", 120), ("7038010053368", 40), ("06.010", 50)]),
            meal("Matpakke med makrell i tomat", "lunsj", [("05.342", 120), ("7039010016322", 80), ("06.010", 50), ("06.622", 150)]),
            meal("Knekkebrød med ost og tomat", "lunsj", [("7300400129459", 48), ("7038010053368", 40), ("06.069", 100), ("06.525", 120)]),
            meal("Ovnsbakt laks med poteter", "middag", [("04.342", 180), ("06.262", 300), ("06.725", 150)]),
            meal("Kylling med ris og brokkoli", "middag", [("03.481", 180), ("05.337", 250), ("06.725", 150), ("06.524", 70)]),
            meal("Fredagstaco", "middag", [("05.381", 100), ("03.139", 120), ("7038010053368", 25), ("06.069", 80), ("06.736", 50), ("06.524", 60)]),
            meal("Cottage cheese med bær", "snacks", [("7038010054471", 150), ("06.502", 75), ("7036110008844", 20)]),
            meal("Turpause med Kvikk Lunsj", "snacks", [("7622210816672", 47), ("06.622", 150)])
        ]
    }
}
