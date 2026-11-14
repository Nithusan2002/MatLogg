import Foundation

protocol HealthReadRepository<Snapshot> {
    associatedtype Snapshot: HealthReadSnapshot

    var availability: HealthDataAvailability { get }
    func example(in range: DateInterval, through date: Date) -> Snapshot?
    func requestAccess() async throws
    func read(in range: DateInterval, through date: Date) async throws -> Snapshot
}

extension HealthReadRepository {
    func example(in range: DateInterval, through date: Date) -> Snapshot? { nil }
}

protocol HealthConnectionRepository {
    func isEnabled(owner: UUID) -> Bool
    func setEnabled(_ enabled: Bool, owner: UUID) throws
}

struct UserDefaultsHealthConnectionRepository: HealthConnectionRepository {
    let defaults: UserDefaults
    let kind: HealthReadKind

    func isEnabled(owner: UUID) -> Bool { defaults.bool(forKey: kind.preferenceKey(owner: owner)) }

    func setEnabled(_ enabled: Bool, owner: UUID) throws {
        defaults.set(enabled, forKey: kind.preferenceKey(owner: owner))
    }
}

struct DemoHealthReadRepository<Snapshot: HealthReadSnapshot>: HealthReadRepository {
    var makeExample: ((DateInterval, Date) -> Snapshot)? = nil
    var availability: HealthDataAvailability { .demo }
    func example(in range: DateInterval, through date: Date) -> Snapshot? { makeExample?(range, date) }
    func requestAccess() async throws { throw CocoaError(.featureUnsupported) }
    func read(in range: DateInterval, through date: Date) async throws -> Snapshot {
        throw CocoaError(.featureUnsupported)
    }
}
