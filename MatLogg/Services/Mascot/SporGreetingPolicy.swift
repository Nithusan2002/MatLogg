import Foundation

@MainActor protocol SporGreetingStoring: AnyObject {
    var lastHomeGreeting: Date? { get set }
}

@MainActor final class SporGreetingPreferences: SporGreetingStoring {
    private let defaults: UserDefaults
    init(defaults: UserDefaults) { self.defaults = defaults }
    var lastHomeGreeting: Date? {
        get { defaults.object(forKey: "spor.lastHomeGreeting") as? Date }
        set { defaults.set(newValue, forKey: "spor.lastHomeGreeting") }
    }
}

nonisolated enum SporGreetingPolicy {
    static func allows(now: Date, last: Date?, calendar: Calendar) -> Bool {
        guard let last else { return true }
        // A clock moved backwards must not repeatedly trigger a greeting.
        return calendar.startOfDay(for: now) > calendar.startOfDay(for: last)
    }
}
