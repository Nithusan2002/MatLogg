import Foundation

protocol HealthReadRepository<Snapshot> {
    associatedtype Snapshot: HealthReadSnapshot

    var availability: HealthDataAvailability { get }
    func requestAccess() async throws
    func read(in range: DateInterval, through date: Date) async throws -> Snapshot
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
    var availability: HealthDataAvailability { .demo }
    func requestAccess() async throws { throw CocoaError(.featureUnsupported) }
    func read(in range: DateInterval, through date: Date) async throws -> Snapshot {
        throw CocoaError(.featureUnsupported)
    }
}
