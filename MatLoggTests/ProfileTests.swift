import Foundation
import Testing
import SwiftUI
@testable import MatLogg

@MainActor
struct ProfileTests {
    @Test func appearanceDefaultsToSystemAndPersistsAllChoices() throws {
        let suite = "AppearanceTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let vm = PreferencesViewModel(defaults: defaults)
        #expect(vm.appearance == .system)
        #expect(vm.appearance.colorScheme == nil)
        for appearance in AppAppearance.allCases {
            vm.appearance = appearance
            #expect(PreferencesViewModel(defaults: defaults).appearance == appearance)
        }
        #expect(AppAppearance.light.colorScheme == .light)
        #expect(AppAppearance.dark.colorScheme == .dark)
        defaults.set("unknown", forKey: "appAppearance")
        #expect(PreferencesViewModel(defaults: defaults).appearance == .system)
    }

    @Test func appleNameSuggestionRequiresExplicitUseAndPreservesEditedName() {
        let vm = PersonalDetailsViewModel(store: ProfileDetailsStoreStub())
        vm.begin(details: .empty, userId: UUID())
        #expect(vm.displayName.isEmpty)
        #expect(vm.useSuggestedName("  Test Navn  "))
        #expect(vm.displayName == "Test Navn")
        vm.displayName = "Mitt navn"
        #expect(!vm.useSuggestedName("Apple Navn"))
        #expect(vm.displayName == "Mitt navn")
        vm.displayName = ""
        #expect(!vm.useSuggestedName("  "))
    }

    @Test func appleNameSuggestionSurvivesMissingNameAndNeverCrossesOwners() throws {
        let account = User(id: UUID(), email: "test@example.invalid", firstName: "", lastName: "", authProvider: "apple", createdAt: Date())
        let shared = account.preservingAppleNameSuggestion(sharedName: "  Test Navn  ", previous: nil)
        #expect(shared.appleDisplayNameSuggestion == "Test Navn")
        let restored = account.preservingAppleNameSuggestion(previous: shared)
        #expect(restored.appleDisplayNameSuggestion == "Test Navn")
        #expect(account.preservingAppleNameSuggestion(sharedName: "Nytt navn", previous: shared).appleDisplayNameSuggestion == "Test Navn")
        let other = User(id: UUID(), email: "other@example.invalid", firstName: "", lastName: "", authProvider: "apple", createdAt: Date())
        #expect(other.preservingAppleNameSuggestion(previous: shared).appleDisplayNameSuggestion == nil)
        #expect(User.local(id: account.id).preservingAppleNameSuggestion(previous: shared).appleDisplayNameSuggestion == nil)
        let encoded = try JSONEncoder().encode(shared)
        #expect(try JSONDecoder().decode(User.self, from: encoded).appleDisplayNameSuggestion == "Test Navn")
        let oldData = try JSONEncoder().encode(account)
        #expect(try JSONDecoder().decode(User.self, from: oldData).appleDisplayNameSuggestion == nil)
    }

    @Test func optionalNameSurvivesReopeningAndIsScopedToItsOwner() throws {
        let suite = "ProfileNameTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsPersonalDetailsStore(defaults: defaults)
        let owner = UUID()
        let vm = PersonalDetailsViewModel(store: store)
        vm.begin(details: .empty, userId: owner)
        vm.displayName = "  Test Navn  "
        #expect(vm.save())
        vm.begin(details: store.load(userId: owner), userId: owner)
        #expect(vm.displayName == "Test Navn")
        #expect(vm.birthDate == nil)
        #expect(store.load(userId: UUID()).displayName == nil)
        vm.displayName = "  "
        #expect(vm.save())
        #expect(store.load(userId: owner).displayName == nil)
    }

    @Test func oldDetailsDecodeWithoutAName() throws {
        let details = try JSONDecoder().decode(PersonalDetails.self, from: Data("{}".utf8))
        #expect(details.displayName == nil)
    }

    @Test func nameCanBeSavedWithoutBirthDateAndOtherDetailsStayOptional() {
        let store = ProfileDetailsStoreStub()
        let userId = UUID()
        var accepted: PersonalDetails?
        let vm = PersonalDetailsViewModel(store: store) { accepted = $0 }
        vm.begin(details: .empty, userId: userId)
        #expect(vm.birthDate == nil)
        vm.displayName = "Test Navn"
        #expect(vm.save())
        #expect(vm.errors.isEmpty)
        #expect(store.owner == userId)
        #expect(accepted?.displayName == "Test Navn")
        #expect(store.details.birthDate == nil)
        vm.begin(details: store.details, userId: userId)
        #expect(vm.displayName == "Test Navn")
        #expect(vm.birthDate == nil)
        let birthDate = Date(timeIntervalSince1970: 1)
        vm.birthDate = birthDate
        #expect(vm.save())
        #expect(vm.errors.isEmpty)
        #expect(store.owner == userId)
        #expect(accepted?.birthDate == birthDate)
        #expect(store.details.weightKg == nil)
        #expect(store.details.heightCm == nil)
        #expect(store.details.gender == nil)
        #expect(store.details.activityLevel == nil)
    }

    @Test(arguments: ["-5", "0", "nan", "inf", "feil"])
    func invalidNumbersDoNotOverwriteStoredDetails(value: String) {
        let store = ProfileDetailsStoreStub()
        let vm = PersonalDetailsViewModel(store: store)
        vm.begin(details: .empty, userId: UUID())
        vm.birthDate = Date(timeIntervalSince1970: 1)
        vm.weight = value
        vm.height = value
        #expect(!vm.save())
        #expect(vm.errors.count == 2)
        #expect(store.owner == nil)
        #expect(vm.weight == value)
    }

    @Test func failureRetainsDraftAndRetryPublishesOnlyAfterSuccess() {
        let store = ProfileDetailsStoreStub()
        store.shouldFail = true
        var publications = 0
        let vm = PersonalDetailsViewModel(store: store) { _ in publications += 1 }
        vm.begin(details: .empty, userId: UUID())
        vm.birthDate = Date(timeIntervalSince1970: 1)
        vm.displayName = "Test Navn"
        vm.weight = "72,25"
        vm.height = "180"
        #expect(!vm.save())
        #expect(vm.displayName == "Test Navn")
        #expect(vm.weight == "72,25")
        #expect(vm.errorMessage != nil)
        #expect(publications == 0)
        store.shouldFail = false
        #expect(vm.save())
        #expect(store.details.weightKg == 72.25)
        #expect(publications == 1)
    }

    @Test func futureBirthDateAndMissingOwnerAreRejected() {
        let store = ProfileDetailsStoreStub()
        let vm = PersonalDetailsViewModel(store: store)
        vm.begin(details: .empty, userId: UUID())
        vm.birthDate = Date().addingTimeInterval(86_400)
        #expect(!vm.save())
        #expect(vm.errors["birthDate"] != nil)
        vm.begin(details: PersonalDetails(birthDate: Date(timeIntervalSince1970: 1)), userId: nil)
        #expect(!vm.save())
        #expect(vm.errorMessage != nil)
        #expect(store.owner == nil)
    }

    @Test func reOpeningStartsFromSavedDetailsRatherThanAnOldDraft() {
        let vm = PersonalDetailsViewModel(store: ProfileDetailsStoreStub())
        vm.begin(details: PersonalDetails(weightKg: 70, birthDate: Date(timeIntervalSince1970: 1)), userId: UUID())
        vm.weight = "99"
        vm.begin(details: .empty, userId: UUID())
        #expect(vm.weight.isEmpty)
        #expect(vm.birthDate == nil)
    }

    @Test func unchangedDetailsKeepTheirPrecision() {
        let store = ProfileDetailsStoreStub()
        let vm = PersonalDetailsViewModel(store: store)
        let details = PersonalDetails(weightKg: 72.123456789, heightCm: 180.123456789, birthDate: Date(timeIntervalSince1970: 1))
        vm.begin(details: details, userId: UUID())
        #expect(vm.save())
        #expect(store.details.weightKg == details.weightKg)
        #expect(store.details.heightCm == details.heightCm)
    }

    @Test func expiredExportCleanupPreservesFreshAndUnrelatedFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stale = directory.appendingPathComponent("matlogg-export-old.json")
        let fresh = directory.appendingPathComponent("matlogg-export-new.json")
        let unrelated = directory.appendingPathComponent("other.json")
        for file in [stale, fresh, unrelated] { try Data("{}".utf8).write(to: file) }
        let now = Date()
        for file in [stale, unrelated] {
            try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-90_000)], ofItemAtPath: file.path)
        }
        UserDataExportService.cleanupExpiredExports(in: directory, now: now)
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(FileManager.default.fileExists(atPath: fresh.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @Test func profileChangeDiscardsAnExportThatFinishesLater() async {
        let exporter = ProfileExporterStub()
        exporter.shouldSuspend = true
        let vm = ProfileExportViewModel(exporter: exporter)
        let task = Task { await vm.export(user: User.local(id: UUID())) }
        while exporter.continuation == nil { await Task.yield() }
        vm.reset()
        let url = URL(fileURLWithPath: "/tmp/discarded-profile-export.json")
        exporter.continuation?.resume(returning: url)
        await task.value
        #expect(vm.document == nil)
        #expect(exporter.removed == url)
        #expect(!vm.isExporting)
    }

    @Test func exportFailureIsVisibleAndCanBeRetried() async {
        let exporter = ProfileExporterStub()
        let vm = ProfileExportViewModel(exporter: exporter)
        let user = User.local(id: UUID())
        await vm.export(user: user)
        #expect(vm.errorMessage != nil)
        #expect(!vm.isExporting)
        #expect(vm.document == nil)
        exporter.url = URL(fileURLWithPath: "/tmp/profile-test.json")
        await vm.export(user: user)
        #expect(vm.errorMessage == nil)
        #expect(vm.document?.url == exporter.url)
        vm.document = nil // SwiftUI clears the sheet binding before onDismiss.
        vm.clearDocument()
        #expect(vm.document == nil)
        #expect(exporter.removed == exporter.url)
    }

    @Test func exportIncludesHealthDetailsAndFavoritesOnlyForItsOwner() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "PrivacyExportTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("profile.sqlite")), defaults: defaults)
        let user = User.local(id: UUID())
        let other = UUID()
        let detailsStore = ProfileDetailsStoreStub()
        detailsStore.details = PersonalDetails(weightKg: 72, heightCm: 180)
        try await database.saveGoal(Goal(userId: user.id, goalType: "maintain", dailyCalories: 2100,
                                         proteinTargetG: 100, carbsTargetG: 250, fatTargetG: 70))
        try await database.saveWeightEntry(WeightEntry(userId: user.id, date: Date(), weightKg: 72))
        try await database.saveWeightEntry(WeightEntry(userId: other, date: Date(), weightKg: 90))
        let product = Product(name: "Testvare", caloriesPer100g: 100, proteinGPer100g: 5,
                              carbsGPer100g: 10, fatGPer100g: 4)
        try await database.saveProduct(product, ownerUserId: user.id)
        let image = Data([7, 8, 9])
        let ownProduct = Product(name: "Egen bildevare", caloriesPer100g: 10, proteinGPer100g: 1,
                                 carbsGPer100g: 1, fatGPer100g: 1, localImageData: image)
        try await database.saveProduct(ownProduct, ownerUserId: user.id)
        try await database.saveProduct(Product(name: "Privat annen vare", caloriesPer100g: 20,
                                                proteinGPer100g: 1, carbsGPer100g: 1, fatGPer100g: 1), ownerUserId: other)
        try await database.saveGoal(Goal(userId: user.id, goalType: "maintain", dailyCalories: 2100,
                                         proteinTargetG: 110, carbsTargetG: 250, fatTargetG: 70))
        try await database.saveGoal(Goal(userId: other, goalType: "maintain", dailyCalories: 2500,
                                         proteinTargetG: 100, carbsTargetG: 250, fatTargetG: 70))
        try await database.saveScanHistory(userId: user.id, productId: ownProduct.id)
        try await database.saveScanHistory(userId: other, productId: product.id)
        let ownPreferenceKey = "lastAmount.\(user.id.uuidString).\(ownProduct.id.uuidString)"
        defaults.set(100.0, forKey: ownPreferenceKey)
        defaults.set(200.0, forKey: "lastAmount.\(other.uuidString).\(product.id.uuidString)")
        try await database.toggleFavorite(userId: user.id, productId: product.id)
        let photo = Data([1, 2, 3])
        let meal = SavedMeal(userId: user.id, name: "Testmåltid", items: [], localImageData: photo)
        try await database.saveSavedMeal(meal)
        try await database.saveSavedMeal(SavedMeal(userId: other, name: "Annen profil", items: [], localImageData: Data([9])))
        let ownWater = WaterGlass(userId: user.id, date: Date())
        try await database.saveWaterGlass(ownWater)
        try await database.saveWaterGlass(WaterGlass(userId: other, date: Date()))
        let exporter = UserDataExportService(logRepository: database, savedMealRepository: database,
            waterRepository: database, healthRepository: database, productRepository: database,
            personalDetailsStore: detailsStore, profileDataRepository: database)
        let url = try #require(await exporter.export(for: user))
        #if !targetEnvironment(simulator)
        // Simulator host files do not expose iOS Data Protection attributes.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        let databaseAttributes = try FileManager.default.attributesOfItem(atPath: directory.appendingPathComponent("profile.sqlite").path)
        #expect(databaseAttributes[.protectionKey] as? FileProtectionType == .completeUntilFirstUserAuthentication)
        #endif
        defer { try? FileManager.default.removeItem(at: url) }
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let exportedMeals = try #require(json["saved_meals"] as? [[String: Any]])
        #expect(exportedMeals.count == 1)
        #expect(exportedMeals.first?["local_image_jpeg_base64"] as? String == photo.base64EncodedString())
        #expect((json["daily_goal"] as? [String: Any])?["dailyCalories"] as? Int == 2100)
        #expect((json["weight_entries"] as? [[String: Any]])?.count == 1)
        #expect((json["personal_details"] as? [String: Any])?["weightKg"] as? Int == 72)
        #expect((json["favorites"] as? [[String: Any]])?.count == 1)
        let ownedProducts = try #require(json["owned_products"] as? [[String: Any]])
        #expect(ownedProducts.count == 2)
        #expect(ownedProducts.contains { ($0["localImageData"] as? String) == image.base64EncodedString() })
        #expect(!ownedProducts.contains { ($0["name"] as? String) == "Privat annen vare" })
        #expect((json["goal_history"] as? [[String: Any]])?.count == 2)
        #expect((json["scan_history"] as? [[String: Any]])?.count == 1)
        let preferences = try #require(json["profile_preferences"] as? [[String: Any]])
        #expect(preferences.count == 1)
        #expect(preferences.first?["key"] as? String == ownPreferenceKey)
        #expect(json["export_schema_version"] as? Int == 2)
        let water = try #require(json["water_glasses"] as? [[String: Any]])
        #expect(water.count == 1)
        #expect(water.first?["id"] as? String == ownWater.id.uuidString)
        exporter.removeExport(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let failingExporter = UserDataExportService(logRepository: database, savedMealRepository: database,
            waterRepository: database, healthRepository: database, productRepository: database,
            personalDetailsStore: detailsStore, profileDataRepository: FailingProfileExportRepository())
        #expect(await failingExporter.export(for: user) == nil)
        let vm = ProfileFavoritesViewModel(repository: database)
        await vm.load(userId: user.id)
        #expect(vm.products.count == 1)
        await vm.load(userId: other)
        #expect(vm.products.isEmpty)
        try await database.deleteLocalData(ownerId: user.id)
        let deletedRecords = try await database.exportProfileRecords(ownerId: user.id)
        #expect(deletedRecords.values.allSatisfy { $0.isEmpty })
        let preservedRecords = try await database.exportProfileRecords(ownerId: other)
        #expect(preservedRecords["owned_products"]?.count == 1)
        #expect(preservedRecords["goal_history"]?.count == 1)
        #expect(preservedRecords["scan_history"]?.count == 1)
        #expect(preservedRecords["profile_preferences"]?.count == 1)
        #expect(await database.getWeightEntries(userId: user.id).isEmpty)
        #expect(await database.getWeightEntries(userId: other).count == 1)
        #expect(await database.getSavedMeals(userId: user.id).isEmpty)
        #expect(await database.getSavedMeals(userId: other).count == 1)
        #expect(await database.fetchPendingEvents(ownerUserId: user.id, limit: 100).isEmpty)
        #expect(!(await database.fetchPendingEvents(ownerUserId: other, limit: 100)).isEmpty)
    }
}

private struct FailingProfileExportRepository: ProfileDataExportRepository {
    func exportProfileRecords(ownerId: UUID) async throws -> [String: [Data]] {
        throw CocoaError(.fileReadCorruptFile)
    }
}

private final class ProfileDetailsStoreStub: PersonalDetailsStore {
    var details: PersonalDetails = .empty
    var owner: UUID?
    var shouldFail = false
    func load(userId: UUID) -> PersonalDetails { details }
    func save(_ details: PersonalDetails, userId: UUID) throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        self.details = details
        owner = userId
    }
}

@MainActor
private final class ProfileExporterStub: UserDataExporting {
    var url: URL?
    var removed: URL?
    var shouldSuspend = false
    var continuation: CheckedContinuation<URL?, Never>?
    func export(for user: User) async -> URL? {
        if shouldSuspend {
            return await withCheckedContinuation { continuation = $0 }
        }
        return url
    }
    func removeExport(at url: URL) { removed = url }
}
