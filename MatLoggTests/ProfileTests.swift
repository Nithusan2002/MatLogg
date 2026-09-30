import Foundation
import Testing
@testable import MatLogg

@MainActor
struct ProfileTests {
    @Test func emptyDetailsStayOptionalAndAreSavedForTheActiveOwner() {
        let store = ProfileDetailsStoreStub()
        let userId = UUID()
        var accepted: PersonalDetails?
        let vm = PersonalDetailsViewModel(store: store) { accepted = $0 }
        vm.begin(details: .empty, userId: userId)
        #expect(vm.birthDate == nil)
        #expect(vm.save())
        #expect(store.owner == userId)
        #expect(accepted?.birthDate == nil)
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
        vm.weight = "72,25"
        vm.height = "180"
        #expect(!vm.save())
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
        vm.begin(details: .empty, userId: nil)
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
        let details = PersonalDetails(weightKg: 72.123456789, heightCm: 180.123456789)
        vm.begin(details: details, userId: UUID())
        #expect(vm.save())
        #expect(store.details.weightKg == details.weightKg)
        #expect(store.details.heightCm == details.heightCm)
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
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("profile.sqlite")))
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
        try await database.toggleFavorite(userId: user.id, productId: product.id)
        let exporter = UserDataExportService(logRepository: database, savedMealRepository: database,
            waterRepository: database, healthRepository: database, productRepository: database,
            personalDetailsStore: detailsStore)
        let url = try #require(await exporter.export(for: user))
        defer { try? FileManager.default.removeItem(at: url) }
        let json = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        #expect((json["daily_goal"] as? [String: Any])?["dailyCalories"] as? Int == 2100)
        #expect((json["weight_entries"] as? [[String: Any]])?.count == 1)
        #expect((json["personal_details"] as? [String: Any])?["weightKg"] as? Int == 72)
        #expect((json["favorites"] as? [[String: Any]])?.count == 1)
        let vm = ProfileFavoritesViewModel(repository: database)
        await vm.load(userId: user.id)
        #expect(vm.products.count == 1)
        await vm.load(userId: other)
        #expect(vm.products.isEmpty)
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
