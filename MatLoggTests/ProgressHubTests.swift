import Foundation
import Testing
@testable import MatLogg

@MainActor
struct ProgressHubTests {
    @Test func fixedLayoutCoversEveryVisibilityCombination() {
        let standard: [ProgressHubArea] = [.nutrition, .steps, .weight, .workouts]
        for mask in 0..<(1 << standard.count) {
            let visible = Set(standard.enumerated().compactMap { index, area in
                mask & (1 << index) != 0 ? area : nil
            })
            let layout = ProgressHubLayout(visible: visible)
            let compact = [ProgressHubArea.steps, .weight].filter { visible.contains($0) }
            let expectedCards = (visible.contains(.nutrition) ? [[ProgressHubArea.nutrition]] : [])
                + (compact.isEmpty ? [] : [compact])
                + (visible.contains(.workouts) ? [[.workouts]] : [])
            let weekRows = [ProgressHubArea.nutrition, .steps, .workouts].filter { visible.contains($0) }
            let expectedWeek = (weekRows.isEmpty ? [] : [weekRows])
                + (visible.contains(.weight) ? [[.weight]] : [])

            #expect(layout.cardGroups(for: .day) == expectedCards)
            #expect(layout.cardGroups(for: .week) == expectedWeek)
            #expect(layout.cardGroups(for: .month) == expectedCards)
        }
    }

    @Test func defaultsFollowHistoryUntilExplicitlySaved() {
        let repository = HubRepositoryStub()
        let model = ProgressHubViewModel(repository: repository)
        let owner = UUID()
        model.activate(owner: owner)
        #expect(model.layout.visibleAreas == [.nutrition])
        model.updateDefault(hasWeightHistory: true, owner: owner)
        #expect(model.layout.visibleAreas == [.nutrition, .weight])
        model.beginEditing()
        model.setVisible(.weight, isVisible: false)
        #expect(model.save())
        model.updateDefault(hasWeightHistory: true, owner: owner)
        #expect(model.layout.visibleAreas == [.nutrition])
    }

    @Test func deletingLastWeightDoesNotRemoveOpenHistoryUntilNextActivation() {
        let model = ProgressHubViewModel(repository: HubRepositoryStub())
        let owner = UUID()
        model.activate(owner: owner)
        model.updateDefault(hasWeightHistory: true, owner: owner)
        model.updateDefault(hasWeightHistory: false, owner: owner)
        #expect(model.layout.visibleAreas == [.nutrition, .weight])
        model.beginEditing()
        model.restoreDefault()
        #expect(model.draft?.visibleAreas == [.nutrition])
        model.reset()
        model.activate(owner: owner)
        model.updateDefault(hasWeightHistory: false, owner: owner)
        #expect(model.layout.visibleAreas == [.nutrition])
    }

    @Test func cancelAndRestoreOperateOnDraftOnly() {
        let model = ProgressHubViewModel(repository: HubRepositoryStub())
        let owner = UUID()
        model.activate(owner: owner)
        model.updateDefault(hasWeightHistory: true, owner: owner)
        model.beginEditing()
        model.setVisible(.nutrition, isVisible: false)
        #expect(model.draft?.visibleAreas == [.weight])
        #expect(model.layout.visibleAreas == [.nutrition, .weight])
        model.cancelEditing()
        #expect(model.layout.visibleAreas == [.nutrition, .weight])
        model.beginEditing()
        model.setVisible(.weight, isVisible: false)
        model.restoreDefault()
        #expect(model.draft == model.layout)
    }

    @Test func reopeningPreservesVisibilityAndValidEmptyLayout() throws {
        try withDefaults { defaults in
            let owner = UUID()
            let repository = UserDefaultsProgressHubRepository(defaults: defaults)
            let model = ProgressHubViewModel(repository: repository)
            model.activate(owner: owner)
            model.beginEditing()
            model.setVisible(.weight, isVisible: true)
            #expect(model.save())
            let reopened = ProgressHubViewModel(repository: repository)
            reopened.activate(owner: owner)
            #expect(reopened.layout.visibleAreas == [.nutrition, .weight])
            reopened.beginEditing()
            reopened.setVisible(.nutrition, isVisible: false)
            reopened.setVisible(.weight, isVisible: false)
            #expect(reopened.save())
            let empty = ProgressHubViewModel(repository: repository)
            empty.activate(owner: owner)
            empty.updateDefault(hasWeightHistory: true, owner: owner)
            #expect(empty.layout.visibleAreas.isEmpty)
        }
    }

    @Test func ownerChangeDiscardsDraftAndRejectsOldDefaults() {
        let model = ProgressHubViewModel(repository: HubRepositoryStub())
        let first = UUID(), second = UUID()
        model.activate(owner: first)
        model.beginEditing()
        model.setVisible(.nutrition, isVisible: false)
        model.activate(owner: second)
        model.updateDefault(hasWeightHistory: true, owner: first)
        #expect(model.draft == nil)
        #expect(model.layout.visibleAreas == [.nutrition])
        #expect(!model.save())
        model.activate(owner: nil)
        model.beginEditing()
        #expect(model.draft == nil)
    }

    @Test func failurePreservesDraftAndSavedLayoutForRetry() {
        let repository = HubRepositoryStub()
        let model = ProgressHubViewModel(repository: repository)
        model.activate(owner: UUID())
        model.beginEditing()
        model.setVisible(.nutrition, isVisible: false)
        repository.fails = true
        #expect(!model.save())
        #expect(model.errorMessage != nil)
        #expect(model.draft?.visibleAreas.isEmpty == true)
        #expect(model.layout.visibleAreas == [.nutrition])
        repository.fails = false
        #expect(model.save())
        #expect(model.layout.visibleAreas.isEmpty)
        #expect(model.errorMessage == nil)
    }

    @Test func malformedUnknownAndDuplicateSettingsAreHandled() throws {
        try withDefaults { defaults in
            let owner = UUID(), other = UUID()
            let repository = UserDefaultsProgressHubRepository(defaults: defaults)
            defaults.set(Data("invalid".utf8), forKey: ProgressHubStorage.key(owner))
            #expect(repository.load(owner: owner) == nil)
            let data = Data(#"{"version":1,"order":["weight","future","weight"],"visible":["weight","future"]}"#.utf8)
            defaults.set(data, forKey: ProgressHubStorage.key(owner))
            #expect(repository.load(owner: owner)?.visibleAreas == [.weight])
            #expect(repository.load(owner: other) == nil)
            defaults.set(Data(#"{"version":9,"order":[],"visible":[]}"#.utf8), forKey: ProgressHubStorage.key(owner))
            #expect(repository.load(owner: owner) == nil)
        }
    }

    @Test func olderPreferencesKeepVisibilityAndAdoptTheFixedOrder() throws {
        try withDefaults { defaults in
            let owner = UUID()
            let repository = UserDefaultsProgressHubRepository(defaults: defaults)
            let key = ProgressHubStorage.key(owner)
            defaults.set(Data(#"{"version":1,"order":["weight","nutrition"],"visible":["weight","nutrition"]}"#.utf8), forKey: key)
            #expect(repository.load(owner: owner)?.visibleAreas == [.nutrition, .weight])
            defaults.set(Data(#"{"version":2,"order":["weight","steps","nutrition"],"visible":["weight","steps"]}"#.utf8), forKey: key)
            let selected = try #require(repository.load(owner: owner))
            #expect(selected.visibleAreas == [.steps, .weight])

            try repository.save(selected, owner: owner)
            let data = try #require(defaults.data(forKey: key))
            let record = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(record["version"] as? Int == 2)
            #expect(record["order"] as? [String] == ["nutrition", "steps", "weight", "workouts"])
            #expect(repository.load(owner: owner) == selected)

            defaults.set(Data(#"{"version":2,"order":["weight","nutrition"],"visible":[]}"#.utf8), forKey: key)
            #expect(repository.load(owner: owner)?.visibleAreas == [])
        }
    }

    @Test func exportClaimDeletionAndResetRespectOwners() async throws {
        let suite = "ProgressHubTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("hub.sqlite")), defaults: defaults)
        let local = UUID(), account = UUID(), other = UUID()
        let repository = UserDefaultsProgressHubRepository(defaults: defaults)
        let selected = ProgressHubLayout(visible: [.weight])
        try repository.save(selected, owner: local)
        try repository.save(.standard(hasWeightHistory: false), owner: other)
        let records = try await database.exportProfileRecords(ownerId: local)
        let preferences = try #require(records["profile_preferences"])
        #expect(preferences.count == 1)
        let json = try #require(JSONSerialization.jsonObject(with: preferences[0]) as? [String: Any])
        #expect(json["key"] as? String == ProgressHubStorage.key(local))
        try await database.claimLocalData(from: local, to: account)
        #expect(repository.load(owner: local) == nil)
        #expect(repository.load(owner: account) == selected)
        // An existing account preference wins when another local profile is claimed.
        try repository.save(.standard(hasWeightHistory: false), owner: local)
        try await database.claimLocalData(from: local, to: account)
        #expect(repository.load(owner: account) == selected)
        try await database.deleteLocalData(ownerId: account)
        #expect(repository.load(owner: account) == nil)
        #expect(repository.load(owner: other) != nil)
        try await database.resetAllLocalData()
        #expect(repository.load(owner: other) == nil)
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "ProgressHubTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}

@MainActor
private final class HubRepositoryStub: ProgressHubRepository {
    var values: [UUID: ProgressHubLayout] = [:]
    var fails = false
    func load(owner: UUID) -> ProgressHubLayout? { values[owner] }
    func save(_ layout: ProgressHubLayout, owner: UUID) throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        values[owner] = layout
    }
}
