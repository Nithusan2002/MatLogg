import Foundation
import SQLite3
import Testing
@testable import MatLogg

@MainActor
struct DomainReadFlowTests {
    @Test func corruptPersonalDetailsAreReportedAndPreserved() throws {
        let suite = "details-read-qa-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let owner = UUID(), corrupt = Data("{".utf8)
        defaults.set(corrupt, forKey: "personalDetails.\(owner)")
        let store = UserDefaultsPersonalDetailsStore(defaults: defaults)
        #expect(throws: Error.self) { try store.load(userId: owner) }
        #expect(defaults.data(forKey: "personalDetails.\(owner)") == corrupt)
        let editor = PersonalDetailsViewModel(store: store)
        editor.begin(details: .empty, userId: owner)
        editor.displayName = "QA"
        #expect(editor.save() == false)
        #expect(defaults.data(forKey: "personalDetails.\(owner)") == corrupt)
        #expect(editor.displayName == "QA")
        #expect(try store.load(userId: UUID()).weightKg == nil)
    }

    @Test func profileRefreshFailureKeepsValuesAndOwnerChangeClearsThem() async throws {
        let repo = DomainHealthRepository(), owner = UUID()
        repo.goal = Goal(userId: owner, goalType: "maintain", dailyCalories: 2000,
                         proteinTargetG: 100, carbsTargetG: 250, fatTargetG: 70)
        repo.weights = [WeightEntry(userId: owner, date: Date(), weightKg: 75)]
        let model = HealthProfileViewModel(repository: repo, personalDetailsStore: DomainDetailsStore())
        await model.loadGoal(userId: owner)
        await model.loadWeightEntries(userId: owner)
        let goal = try #require(model.currentGoal)
        repo.fails = true
        await model.loadGoal(userId: owner)
        await model.loadWeightEntries(userId: owner)
        #expect(model.currentGoal?.id == goal.id)
        #expect(model.weightEntries.count == 1)
        #expect(model.goalLoadError != nil && model.weightLoadError != nil)
        let other = UUID()
        await model.loadGoal(userId: other)
        await model.loadWeightEntries(userId: other)
        model.useDevelopmentGoalIfMissing(userId: other)
        #expect(model.currentGoal == nil && model.weightEntries.isEmpty)
        repo.fails = false
        repo.goal = nil
        repo.weights = []
        await model.loadGoal(userId: other)
        await model.loadWeightEntries(userId: other)
        #expect(model.goalLoadError == nil && model.weightLoadError == nil)
    }

    @Test func favoritesRefreshFailureKeepsListAndRetryRecovers() async throws {
        try await withStore { store, url in
            let database = DatabaseService(store: store), owner = UUID()
            let product = Product(name: "QA", caloriesPer100g: 100, proteinGPer100g: 1, carbsGPer100g: 2, fatGPer100g: 3)
            try store.cacheCatalogProduct(product)
            try store.toggleFavorite(userId: owner, productId: product.id)
            let model = ProfileFavoritesViewModel(repository: database)
            await model.load(userId: owner)
            #expect(model.products.map(\.id) == [product.id])
            try execute("ALTER TABLE favorites RENAME TO unavailable_favorites", at: url)
            await model.load(userId: owner)
            #expect(model.products.map(\.id) == [product.id])
            #expect(model.errorMessage != nil && !model.isLoading)
            try execute("ALTER TABLE unavailable_favorites RENAME TO favorites", at: url)
            await model.load(userId: owner)
            #expect(model.errorMessage == nil)
            try execute("DROP TABLE favorites", at: url)
            await model.load(userId: UUID())
            #expect(model.products.isEmpty && model.errorMessage != nil)
        }
    }

    @Test(arguments: ["goals", "weights", "saved_meals"])
    func exportRejectsCorruptRequiredSource(table: String) async throws {
        try await withStore { store, url in
            let database = DatabaseService(store: store), owner = UUID()
            let user = User(id: owner, email: "qa@example.invalid", firstName: "QA", lastName: "Test", authProvider: "apple", createdAt: Date())
            let column = table == "goals" ? "createdDate" : table == "weights" ? "date" : "updatedAt"
            let nameColumn = table == "saved_meals" ? ",name" : ""
            let nameValue = table == "saved_meals" ? ",'QA'" : ""
            try execute("INSERT INTO \(table)(id,userId,\(column),json\(nameColumn)) VALUES('\(UUID())','\(owner)',0,X'7B'\(nameValue))", at: url)
            let exporter = UserDataExportService(logRepository: database, savedMealRepository: database,
                waterRepository: database, healthRepository: database, productRepository: database,
                personalDetailsStore: DomainDetailsStore(), profileDataRepository: database)
            #expect(await exporter.export(for: user) == nil)
        }
    }

    @Test func editorFavoriteFailurePreservesSnapshotAndRetryClearsError() async {
        let owner = UUID(), repository = DomainFavoriteRepository()
        let log = FoodLog(userId: owner, productId: UUID(), mealType: "frokost", amountG: 100,
                          loggedDate: Date(), calories: 100, proteinG: 1, carbsG: 2, fatG: 3)
        let model = EditLogViewModel(log: log, favorites: repository)
        await model.loadFavorite(owner: owner)
        #expect(model.isFavorite == true)
        repository.fails = true
        await model.loadFavorite(owner: owner)
        #expect(model.isFavorite == true && model.favoriteError != nil)
        #expect(await model.toggleFavorite(owner: owner) == false)
        repository.fails = false
        await model.loadFavorite(owner: owner)
        #expect(model.favoriteError == nil)
        await model.loadFavorite(owner: nil)
        #expect(model.isFavorite == nil)
    }

    private func withStore(_ body: (LocalStore, URL) async throws -> Void) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("domain-flow-qa.sqlite")
        try await body(LocalStore(databaseURL: url, healthWritesEnabled: false, diagnosticHandler: { _ in }), url)
    }
    private func execute(_ sql: String, at url: URL) throws {
        var db: OpaquePointer?
        try #require(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        try #require(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
    }
}

@MainActor
private final class DomainHealthRepository: HealthProfileRepository {
    var fails = false
    var goal: Goal?
    var weights: [WeightEntry] = []
    func latestGoal(userId: UUID) async throws -> Goal? {
        if fails { throw DatabaseServiceError.unavailable }
        return goal
    }
    func getWeightEntries(userId: UUID) async throws -> [WeightEntry] {
        if fails { throw DatabaseServiceError.unavailable }
        return weights
    }
    func saveGoal(_ goal: Goal) async throws {}
    func saveWeightEntry(_ entry: WeightEntry) async throws {}
    func deleteWeightEntry(_ id: UUID) async throws {}
}

private struct DomainDetailsStore: PersonalDetailsStore {
    func load(userId: UUID) -> PersonalDetails { .empty }
    func save(_ details: PersonalDetails, userId: UUID) throws {}
}

@MainActor
private final class DomainFavoriteRepository: ProductFavoriteRepository {
    var fails = false
    func isFavorite(userId: UUID, productId: UUID) async throws -> Bool {
        if fails { throw DatabaseServiceError.unavailable }
        return true
    }
    func toggleFavorite(userId: UUID, productId: UUID) async throws {}
}
