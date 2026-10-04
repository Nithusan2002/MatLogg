import Foundation
import ImageIO
import Testing
@testable import MatLogg

struct DemoModeTests {
    @Test func missingBundledCatalogFailsWithoutPublishingProducts() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID()).bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let info = try PropertyListSerialization.data(
            fromPropertyList: ["CFBundleIdentifier": "app.matlogg.empty-demo-fixture"],
            format: .xml, options: 0
        )
        try info.write(to: directory.appendingPathComponent("Info.plist"))
        let bundle = try #require(Bundle(url: directory))
        await #expect(throws: (any Error).self) {
            _ = try await DemoProductCatalog.load(bundle: bundle)
        }
    }

    @Test func bundledOFFCatalogHasStableIdentityNutritionAndDecodableImages() async throws {
        let products = try await DemoProductCatalog.load()
        let reloaded = try await DemoProductCatalog.load()
        #expect(products.count == 12)
        #expect(Set(products.map(\.id)).count == products.count)
        #expect(products.map(\.id) == reloaded.map(\.id))
        for product in products {
            #expect(product.source == "openfoodfacts")
            #expect(product.nutritionSource == .openFoodFacts)
            #expect(product.imageSource == .openFoodFacts)
            #expect(product.nutritionBasis == .per100g)
            #expect(!product.isVerified)
            #expect(product.externalID == product.barcodeEan)
            #expect(product.caloriesPer100g > 0)
            let data = try #require(product.localImageData)
            let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
            #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
        }
    }

    private func product() -> Product {
        Product(name: "Testmat", caloriesPer100g: 100, proteinGPer100g: 10, carbsGPer100g: 10, fatGPer100g: 2)
    }

    @Test func seedingIsPersistentAndResetDoesNotTouchNormalStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let normal = try LocalStore(databaseURL: directory.appendingPathComponent("normal.sqlite"))
        let owner = UUID()
        try normal.saveWeightEntry(WeightEntry(userId: owner, date: Date(), weightKg: 81))
        let url = directory.appendingPathComponent("demo.sqlite")
        let demoOwner = UUID()
        let demo = try await DemoDataset.prepare(at: url, userId: demoOwner, products: [product()])
        let initialCount = demo.getAllLogs(userId: demoOwner).count
        #expect(initialCount > 400)
        #expect(demo.getAllLogs(userId: owner).isEmpty)
        #expect(!demo.getSummary(userId: demoOwner, date: Date()).logs.isEmpty)
        #expect(demo.getSavedMeals(userId: demoOwner).count == 4)
        #expect(try demo.getWaterGlasses(userId: demoOwner).count > 200)
        let weight = WeightEntry(userId: demoOwner, date: Date(), weightKg: 99)
        try demo.saveWeightEntry(weight)
        let reopened = try await DemoDataset.prepare(at: url, userId: demoOwner, products: [])
        #expect(reopened.getAllLogs(userId: demoOwner).count == initialCount)
        #expect(reopened.getWeightEntries(userId: demoOwner).contains { $0.id == weight.id })
        await #expect(throws: (any Error).self) {
            _ = try await DemoDataset.prepare(at: url, userId: demoOwner, products: [], reset: true)
        }
        #expect(reopened.getWeightEntries(userId: demoOwner).contains { $0.id == weight.id })
        let reset = try await DemoDataset.prepare(at: url, userId: demoOwner, products: [product()], reset: true)
        #expect(reset.getAllLogs(userId: demoOwner).count == initialCount)
        #expect(!reset.getWeightEntries(userId: demoOwner).contains { $0.id == weight.id })
        #expect(normal.getWeightEntries(userId: owner).first?.weightKg == 81)
    }

    @Test func personalDetailsStayInTheirDefaultsSuite() throws {
        let name = "demo-test-\(UUID())"
        let otherName = "normal-test-\(UUID())"
        let demoDefaults = try #require(UserDefaults(suiteName: name))
        let normalDefaults = try #require(UserDefaults(suiteName: otherName))
        defer {
            demoDefaults.removePersistentDomain(forName: name)
            normalDefaults.removePersistentDomain(forName: otherName)
        }
        let owner = UUID()
        let demo = UserDefaultsPersonalDetailsStore(defaults: demoDefaults)
        let normal = UserDefaultsPersonalDetailsStore(defaults: normalDefaults)
        var details = PersonalDetails.empty
        details.weightKg = 74
        try demo.save(details, userId: owner)
        #expect(demo.load(userId: owner).weightKg == 74)
        #expect(normal.load(userId: owner).weightKg == nil)
    }
}

@MainActor
struct DemoContextTests {
    @Test func switchingPreservesNormalIdentityAndBlocksDemoSync() async throws {
        let suite = "selection-\(UUID())"
        let demoSuite = "demo-\(UUID())"
        let selection = try #require(UserDefaults(suiteName: suite))
        let demo = try #require(UserDefaults(suiteName: demoSuite))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            selection.removePersistentDomain(forName: suite)
            demo.removePersistentDomain(forName: demoSuite)
            try? FileManager.default.removeItem(at: directory)
        }
        let normalUser = AuthService(defaults: selection).activateLocalProfile()
        let mode = DemoMode(selectionDefaults: selection, demoDefaults: demo, directory: directory)
        await mode.selectDemo(true)
        #expect(mode.isDemo)
        let demoUser = try #require(AuthService(defaults: demo).getActiveLocalProfile())
        #expect(demoUser.id != normalUser.id)
        let initialRevision = mode.revision
        let engine = SyncEngine(databaseService: mode.database, apiService: UnavailableSyncAPIClient(), syncEnabled: { !mode.isDemo })
        engine.updateActiveOwner(demoUser.id)
        let before = await mode.database.fetchPendingEvents(ownerUserId: demoUser.id, limit: 1000)
        let result = await engine.syncPendingEvents(ownerUserId: demoUser.id)
        #expect(!result.success)
        #expect(!engine.isUploadAvailable)
        #expect(result.errorMessage != nil)
        let after = await mode.database.fetchPendingEvents(ownerUserId: demoUser.id, limit: 1000)
        #expect(before.count == after.count)
        await mode.selectDemo(false)
        #expect(!mode.isDemo)
        #expect(mode.revision != initialRevision)
        #expect(AuthService(defaults: selection).getActiveLocalProfile()?.id == normalUser.id)
        await mode.selectDemo(true)
        #expect(AuthService(defaults: demo).getActiveLocalProfile()?.id == demoUser.id)
    }

    @Test func catalogFailureKeepsCurrentContext() async throws {
        let name = "failure-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let mode = DemoMode(selectionDefaults: defaults, demoDefaults: defaults, directory: FileManager.default.temporaryDirectory, loadCatalog: { throw CocoaError(.fileReadNoSuchFile) })
        let revision = mode.revision
        await mode.selectDemo(true)
        #expect(!mode.isDemo)
        #expect(mode.revision == revision)
        #expect(mode.errorMessage != nil)
        #expect(!mode.isLoading)
    }
}
