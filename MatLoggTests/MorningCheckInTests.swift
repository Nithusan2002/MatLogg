import Foundation
import Testing
@testable import MatLogg

@MainActor
struct MorningCheckInTests {
    private func setup() -> (MorningCheckInViewModel, CheckInRepositoryStub, UserDefaults) {
        let defaults = UserDefaults(suiteName: "MorningCheckInTests.\(UUID())")!
        let repository = CheckInRepositoryStub()
        return (MorningCheckInViewModel(repository: repository,
                                       store: UserDefaultsMorningCheckInStore(defaults: defaults)), repository, defaults)
    }

    @Test func optionalWeightAndDayAndOwnerIsolation() async {
        let (vm, repository, defaults) = setup()
        let owner = UUID()
        let day = Date()
        await vm.load(userId: owner, date: day)
        #expect(await vm.finish())
        #expect(repository.saved.isEmpty)
        #expect(vm.status == "completed")
        let reopened = MorningCheckInViewModel(repository: repository, store: UserDefaultsMorningCheckInStore(defaults: defaults))
        await reopened.load(userId: owner, date: day)
        #expect(reopened.status == "completed")
        await vm.load(userId: UUID(), date: day)
        #expect(vm.status == nil)
        await vm.load(userId: owner, date: Calendar.current.date(byAdding: .day, value: 1, to: day)!)
        #expect(vm.status == nil)
        vm.skip()
        #expect(vm.status == "skipped")
    }

    @Test func validatesWeightAndRetriesFailureWithoutCompleting() async {
        let (vm, repository, _) = setup()
        await vm.load(userId: UUID(), date: Date())
        for invalid in ["abc", "0", "-5", "nan", "inf", "501"] {
            vm.weightText = invalid
            #expect(await vm.finish() == false)
            #expect(vm.errorMessage != nil)
        }
        #expect(repository.saved.isEmpty)
        vm.weightText = "72,5"
        repository.shouldFail = true
        #expect(await vm.finish() == false)
        #expect(vm.status == nil)
        #expect(vm.weightText == "72,5")
        repository.shouldFail = false
        #expect(await vm.finish())
        #expect(repository.saved.last?.weightKg == 72.5)
        #expect(vm.status == "completed")
        #expect(await vm.finish())
        #expect(repository.saved.count == 1)
    }

    @Test func editReusesExistingWeightIDAndEmptyFieldDoesNotDelete() async {
        let (vm, repository, _) = setup()
        let owner = UUID()
        let entry = WeightEntry(userId: owner, date: Date(), weightKg: 75)
        repository.entries = [entry]
        await vm.load(userId: owner, date: Date())
        vm.begin()
        #expect(vm.weightText == "75,0")
        vm.weightText = "74,8"
        #expect(await vm.finish())
        #expect(repository.saved.last?.id == entry.id)
        #expect(repository.saved.last?.createdAt == entry.createdAt)
        vm.weightText = ""
        #expect(await vm.finish())
        #expect(repository.saved.count == 1)
    }

    @Test func localWeightWriteQueuesEventAndUpdatesSameEntry() async throws {
        let defaults = UserDefaults(suiteName: "MorningCheckInTests.\(UUID())")!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("checkin.sqlite")), defaults: defaults)
        let vm = MorningCheckInViewModel(repository: database, store: UserDefaultsMorningCheckInStore(defaults: defaults))
        let owner = UUID()
        await vm.load(userId: owner, date: Date())
        vm.weightText = "70,2"
        #expect(await vm.finish())
        let first = try #require(await database.getWeightEntries(userId: owner).first)
        vm.weightText = "70,3"
        #expect(await vm.finish())
        let entries = await database.getWeightEntries(userId: owner)
        #expect(entries.count == 1)
        #expect(entries.first?.id == first.id)
        #expect(entries.first?.weightKg == 70.3)
        let events = await database.fetchPendingEvents(ownerUserId: owner, limit: 10)
        #expect(events.count == 2)
        #expect(events.allSatisfy { $0.type == "weight.upsert" })
        try await database.deleteLocalData(ownerId: owner)
        #expect(await database.getWeightEntries(userId: owner).isEmpty)
        #expect(defaults.object(forKey: UserDefaultsMorningCheckInStore.key(owner)) == nil)
    }
}

private final class CheckInRepositoryStub: HealthProfileRepository {
    var entries: [WeightEntry] = []
    var saved: [WeightEntry] = []
    var shouldFail = false
    func latestGoal(userId: UUID) async -> Goal? { nil }
    func saveGoal(_ goal: Goal) async throws {}
    func getWeightEntries(userId: UUID) async -> [WeightEntry] { entries.filter { $0.userId == userId } }
    func deleteWeightEntry(_ id: UUID) async throws {}
    func saveWeightEntry(_ entry: WeightEntry) async throws {
        if shouldFail { throw CocoaError(.fileWriteUnknown) }
        saved.append(entry)
    }
}
