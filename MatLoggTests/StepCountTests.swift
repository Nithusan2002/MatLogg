import Foundation
import Testing
@testable import MatLogg

@MainActor
struct StepCountTests {
    private let range = DateInterval(start: Date(timeIntervalSince1970: 1_799_900_000), duration: 7 * 86_400)

    @Test func dayUsesHourlyBucketsAcrossClockChangeAndTrendLeavesGaps() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Oslo"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25)))
        let day = try #require(calendar.dateInterval(of: .day, for: date))
        let week = try #require(calendar.dateInterval(of: .weekOfYear, for: date))
        let granularity = StepCountGranularity(range: day, calendar: calendar)
        #expect(day.duration == 25 * 3600)
        #expect(granularity == .hour)
        #expect(StepCountGranularity(range: week, calendar: calendar) == .day)

        let first = StepCountBucket(date: date + 2 * 3600, steps: 0)
        let repeatedHour = StepCountBucket(date: date + 3 * 3600, steps: 120.5)
        let afterGap = StepCountBucket(date: date + 5 * 3600, steps: 31.5)
        let snapshot = StepCountSnapshot(range: day, buckets: [first, repeatedHour, afterGap],
                                         updatedAt: day.end, granularity: granularity)
        #expect(snapshot.trendRuns(calendar: calendar) == [[first, repeatedHour], [afterGap]])
        #expect(snapshot.count == 152)
    }

    @Test func neverRequestsAccessOrReadsUntilExplicitConnection() async {
        let source = StepsSourceStub(), choices = StepsChoicesStub()
        let model = StepCountViewModel(repository: source, connections: choices)
        await model.update(owner: UUID(), isVisible: true, range: range)
        #expect(model.state == .notConnected)
        #expect(source.authorizationCount == 0 && source.readDates.isEmpty)
    }

    @Test func connectionShowsDailyCountAndZeroIsDifferentFromNoData() async {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let model = StepCountViewModel(repository: source, connections: choices, now: { date })
        await model.update(owner: owner, isVisible: true, range: range)
        await model.connect()
        #expect(choices.values[owner] == true)
        #expect(source.authorizationCount == 1)
        #expect(source.readDates == [date])
        guard case .loaded(let snapshot) = model.state else { Issue.record("Expected steps"); return }
        #expect(snapshot.count == 1234)
        source.count = 0
        await model.refresh()
        guard case .loaded(let zero) = model.state else { Issue.record("A real zero must remain data"); return }
        #expect(zero.count == 0)
        source.count = nil
        await model.refresh()
        #expect(model.state == .noData)
        #expect(model.isEnabled)
        // Authorization completion must never be presented as confirmed read access.
        let reopened = StepCountViewModel(repository: source, connections: choices)
        await reopened.update(owner: owner, isVisible: true, range: range)
        #expect(reopened.state == .noData)
        #expect(source.authorizationCount == 1)
    }

    @Test func refreshUsesCurrentDateAndClearsOldValuesOnFailure() async {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        choices.values[owner] = true
        var date = Date(timeIntervalSince1970: 1_800_000_000)
        let model = StepCountViewModel(repository: source, connections: choices, now: { date })
        await model.update(owner: owner, isVisible: true, range: range)
        date = date.addingTimeInterval(86400)
        source.readFails = true
        await model.refresh()
        #expect(source.readDates.last == date)
        #expect(model.state == .failed)
        source.readFails = false
        await model.refresh()
        guard case .loaded = model.state else { Issue.record("Retry should work"); return }
    }

    @Test func unavailableAndDemoNeverTouchHealthData() async {
        for availability in [HealthDataAvailability.unavailable, .demo] {
            let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
            source.availability = availability
            choices.values[owner] = true
            let model = StepCountViewModel(repository: source, connections: choices)
            await model.update(owner: owner, isVisible: true, range: range)
            await model.connect()
            #expect(source.authorizationCount == 0 && source.readDates.isEmpty)
            #expect(model.state == (availability == .demo ? .demo : .unavailable))
        }
    }

    @Test func authorizationAndPreferenceFailuresDoNotEnableReading() async {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        let model = StepCountViewModel(repository: source, connections: choices)
        await model.update(owner: owner, isVisible: true, range: range)
        source.authorizationFails = true
        await model.connect()
        #expect(model.connectionError != nil && !model.isEnabled && !model.isAuthorizing)
        #expect(choices.values[owner] == nil && source.readDates.isEmpty)
        source.authorizationFails = false
        choices.fails = true
        await model.connect()
        #expect(model.connectionError != nil && !model.isEnabled && !model.isAuthorizing)
        #expect(source.readDates.isEmpty)
    }

    @Test func settingsCanEnableHiddenCardWithoutReadingDuringAuthorization() async throws {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        source.delayAuthorization = true
        let model = StepCountViewModel(repository: source, connections: choices)
        model.activate(owner: owner)
        let connection = Task { await model.connect() }
        try await waitUntil { source.pendingAuthorization != nil }
        #expect(model.isAuthorizing)
        // The system prompt can interrupt the scene while Settings is open.
        model.suspend()
        #expect(model.isAuthorizing)
        source.pendingAuthorization?.resume()
        source.pendingAuthorization = nil
        await connection.value
        #expect(model.isEnabled && choices.values[owner] == true)
        #expect(!model.isAuthorizing && model.state == .notConnected)
        #expect(source.readDates.isEmpty)
        await model.update(owner: owner, isVisible: false, range: range)
        #expect(source.readDates.isEmpty)
        await model.update(owner: owner, isVisible: true, range: range)
        #expect(model.snapshot(for: range)?.count == 1234)
        #expect(source.authorizationCount == 1)
    }

    @Test func disconnectAndHideRejectDelayedDataAndStopReading() async throws {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        choices.values[owner] = true
        source.delayReads = true
        let model = StepCountViewModel(repository: source, connections: choices)
        let reading = Task { await model.update(owner: owner, isVisible: true, range: range) }
        try await waitUntil { source.pendingReads.count == 1 }
        model.disconnect()
        source.pendingReads.removeFirst().resume(returning: source.snapshot(in: range, through: Date()))
        await reading.value
        #expect(model.state == .notConnected && !model.isEnabled)
        #expect(choices.values[owner] == false)
        await model.refresh()
        #expect(source.readDates.count == 1)
        choices.values[owner] = true
        model.reset()
        let hiddenRead = Task { await model.update(owner: owner, isVisible: true, range: range) }
        try await waitUntil { source.pendingReads.count == 1 }
        await model.update(owner: owner, isVisible: false, range: range)
        source.pendingReads.removeFirst().resume(returning: source.snapshot(in: range, through: Date()))
        await hiddenRead.value
        #expect(model.state == .notConnected)
        await model.refresh()
        #expect(source.readDates.count == 2)
    }

    @Test func leavingScreenClearsDataWithoutForgettingConnectionChoice() async {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        choices.values[owner] = true
        let model = StepCountViewModel(repository: source, connections: choices)
        await model.update(owner: owner, isVisible: true, range: range)
        model.suspend()
        #expect(model.state == .notConnected && model.isEnabled)
        await model.refresh()
        #expect(source.readDates.count == 1)
        await model.update(owner: owner, isVisible: true, range: range)
        #expect(source.readDates.count == 2)
        #expect(source.authorizationCount == 0)
    }

    @Test func profileChangeRejectsDelayedReadsAndDelayedAuthorization() async throws {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), first = UUID(), second = UUID()
        choices.values[first] = true
        source.delayReads = true
        let model = StepCountViewModel(repository: source, connections: choices)
        let read = Task { await model.update(owner: first, isVisible: true, range: range) }
        try await waitUntil { source.pendingReads.count == 1 }
        await model.update(owner: second, isVisible: true, range: range)
        source.pendingReads.removeFirst().resume(returning: source.snapshot(in: range, through: Date()))
        await read.value
        #expect(model.owner == second && model.state == .notConnected)
        source.delayAuthorization = true
        let authorize = Task { await model.connect() }
        try await waitUntil { source.pendingAuthorization != nil }
        model.reset()
        source.pendingAuthorization?.resume()
        source.pendingAuthorization = nil
        await authorize.value
        #expect(choices.values[second] == nil)
        #expect(model.owner == nil && model.state == .notConnected)
    }

    @Test func latestPeriodWinsDuringPermissionAndOverlappingReads() async throws {
        let source = StepsSourceStub(), choices = StepsChoicesStub(), owner = UUID()
        let model = StepCountViewModel(repository: source, connections: choices)
        await model.update(owner: owner, isVisible: true, range: range)
        source.delayAuthorization = true
        let connect = Task { await model.connect() }
        try await waitUntil { source.pendingAuthorization != nil }
        await model.refresh()
        let previous = DateInterval(start: range.start - range.duration, duration: range.duration)
        await model.update(owner: owner, isVisible: true, range: previous)
        source.pendingAuthorization?.resume()
        source.pendingAuthorization = nil
        await connect.value
        #expect(model.isEnabled)
        #expect(source.readRanges == [previous])
        source.delayReads = true
        let first = Task { await model.refresh() }
        try await waitUntil { source.pendingReads.count == 1 }
        let second = Task { await model.update(owner: owner, isVisible: true, range: range) }
        try await waitUntil { source.pendingReads.count == 2 }
        #expect(source.readRanges == [previous, previous, range])
        #expect(model.state == .loading)
        let days = [
            StepCountBucket(date: range.start, steps: 100.5),
            StepCountBucket(date: range.start + 2 * 86_400, steps: 121.5)
        ]
        source.pendingReads[1].resume(returning: StepCountSnapshot(range: range, buckets: days, updatedAt: Date()))
        await second.value
        source.pendingReads[0].resume(returning: source.snapshot(in: previous, through: Date()))
        await first.value
        guard case .loaded(let snapshot) = model.state else { Issue.record("Expected latest result"); return }
        #expect(snapshot.range == range && snapshot.buckets == days && snapshot.count == 222)
    }

    @Test func onlyConnectionChoiceIsPersistedExportedClaimedAndDeleted() async throws {
        let suite = "StepCountTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = DatabaseService(store: try LocalStore(databaseURL: directory.appendingPathComponent("steps.sqlite")), defaults: defaults)
        let choices = UserDefaultsHealthConnectionRepository(defaults: defaults, kind: .steps)
        let weightChoices = UserDefaultsHealthConnectionRepository(defaults: defaults, kind: .weight)
        let workoutChoices = UserDefaultsHealthConnectionRepository(defaults: defaults, kind: .workouts)
        let local = UUID(), account = UUID(), other = UUID()
        try choices.setEnabled(true, owner: local)
        try choices.setEnabled(true, owner: other)
        #expect(!weightChoices.isEnabled(owner: local))
        #expect(!workoutChoices.isEnabled(owner: local))
        #expect(UserDefaultsHealthConnectionRepository(defaults: defaults, kind: .steps).isEnabled(owner: local))
        let records = try await database.exportProfileRecords(ownerId: local)
        let prefs = try #require(records["profile_preferences"])
        #expect(prefs.count == 1)
        let json = try #require(JSONSerialization.jsonObject(with: prefs[0]) as? [String: Any])
        #expect(json["key"] as? String == HealthReadKind.steps.preferenceKey(owner: local))
        #expect(json["value"] as? Bool == true)
        try weightChoices.setEnabled(true, owner: local)
        try weightChoices.setEnabled(true, owner: other)
        try workoutChoices.setEnabled(true, owner: local)
        try workoutChoices.setEnabled(true, owner: other)
        let healthRecords = try await database.exportProfileRecords(ownerId: local)
        let preferenceRecords = try #require(healthRecords["profile_preferences"])
        let preferenceKeys = try preferenceRecords.map { data in
            (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["key"] as? String
        }
        #expect(preferenceKeys.count == 3)
        #expect(preferenceKeys.contains(HealthReadKind.weight.preferenceKey(owner: local)))
        #expect(preferenceKeys.contains(HealthReadKind.workouts.preferenceKey(owner: local)))
        try await database.claimLocalData(from: local, to: account)
        #expect(!choices.isEnabled(owner: local) && choices.isEnabled(owner: account))
        #expect(!weightChoices.isEnabled(owner: local) && weightChoices.isEnabled(owner: account))
        #expect(!workoutChoices.isEnabled(owner: local) && workoutChoices.isEnabled(owner: account))
        try choices.setEnabled(false, owner: account)
        try choices.setEnabled(true, owner: local)
        try await database.claimLocalData(from: local, to: account)
        #expect(!choices.isEnabled(owner: account))
        try await database.deleteLocalData(ownerId: account)
        #expect(defaults.object(forKey: HealthReadKind.steps.preferenceKey(owner: account)) == nil)
        #expect(defaults.object(forKey: HealthReadKind.weight.preferenceKey(owner: account)) == nil)
        #expect(defaults.object(forKey: HealthReadKind.workouts.preferenceKey(owner: account)) == nil)
        #expect(choices.isEnabled(owner: other))
        try await database.resetAllLocalData()
        #expect(!choices.isEnabled(owner: other))
        #expect(!weightChoices.isEnabled(owner: other))
        #expect(!workoutChoices.isEnabled(owner: other))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<1000 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Timed out waiting for stub")
    }
}

@MainActor
private final class StepsSourceStub: HealthReadRepository {
    var availability: HealthDataAvailability = .available
    var count: Int? = 1234
    var authorizationCount = 0
    var readDates: [Date] = []
    var readRanges: [DateInterval] = []
    var readFails = false
    var authorizationFails = false
    var delayReads = false
    var delayAuthorization = false
    var pendingReads: [CheckedContinuation<StepCountSnapshot, Error>] = []
    var pendingAuthorization: CheckedContinuation<Void, Error>?
    func requestAccess() async throws {
        authorizationCount += 1
        if authorizationFails { throw CocoaError(.userCancelled) }
        if delayAuthorization { try await withCheckedThrowingContinuation { pendingAuthorization = $0 } }
    }
    func read(in range: DateInterval, through date: Date) async throws -> StepCountSnapshot {
        readDates.append(date)
        readRanges.append(range)
        if readFails { throw CocoaError(.fileReadNoPermission) }
        if delayReads { return try await withCheckedThrowingContinuation { pendingReads.append($0) } }
        return snapshot(in: range, through: date)
    }
    func snapshot(in range: DateInterval, through date: Date) -> StepCountSnapshot {
        let days = count.map { [StepCountBucket(date: range.start, steps: Double($0))] } ?? []
        return StepCountSnapshot(range: range, buckets: days, updatedAt: date)
    }
}

@MainActor
private final class StepsChoicesStub: HealthConnectionRepository {
    var values: [UUID: Bool] = [:]
    var fails = false
    func isEnabled(owner: UUID) -> Bool { values[owner] ?? false }
    func setEnabled(_ enabled: Bool, owner: UUID) throws {
        if fails { throw CocoaError(.fileWriteUnknown) }
        values[owner] = enabled
    }
}
