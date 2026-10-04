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
                let url = directory.appendingPathComponent("demo-v1.sqlite")
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
        try await BackgroundWork.run {
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
    }

    static func amountG(for product: Product, offset: Int, index: Int) -> Float {
        let portions: [String: Float] = [
            "7044416013141": 60, "7038010045073": 150, "7300400129459": 36,
            "7038010053368": 30, "7036110004785": 60, "7039010016322": 100,
            "7039010132435": 25, "7036110008844": 20, "7038010054471": 100,
            "7039317005470": 30, "7622210816672": 24, "4000339697908": 25
        ]
        guard let code = product.externalID, let portion = portions[code] else {
            return Float(60 + (offset + index * 7) % 180)
        }
        return portion * (1 + Float(offset % 3) * 0.1)
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
        let chosen = Array(products.prefix(12))
        for product in chosen { try store.cacheCatalogProduct(product) }
        try store.saveGoal(Goal(userId: userId, goalType: "maintain", dailyCalories: 2200, proteinTargetG: 110, carbsTargetG: 275, fatTargetG: 73))
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for offset in 0..<56 {
            try Task.checkCancellation()
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if offset % 13 == 5 { continue }
            let count = offset % 9 == 4 ? 2 : 9 + offset % 3
            var logs: [FoodLog] = []
            for index in 0..<count {
                let menu = [0, 1, 2, 3, 4, 5, 8, 9, offset % 2 == 0 ? 7 : 6, 11, 10]
                let product = chosen[menu[index % menu.count] % chosen.count]
                let amount = DemoProductCatalog.amountG(for: product, offset: offset, index: index)
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
