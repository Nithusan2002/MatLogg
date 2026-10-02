import Foundation

// A single day of local presentation preferences, never a health history.
protocol MorningCheckInStore {
    func status(userId: UUID, day: Date) -> String?
    func setStatus(_ status: String, userId: UUID, day: Date)
}

struct UserDefaultsMorningCheckInStore: MorningCheckInStore {
    var defaults: UserDefaults
    static func key(_ userId: UUID) -> String { "morningCheckIn.\(userId.uuidString)" }

    func status(userId: UUID, day: Date) -> String? {
        let value = defaults.dictionary(forKey: Self.key(userId))
        guard value?["day"] as? Double == day.timeIntervalSince1970 else { return nil }
        return value?["status"] as? String
    }

    func setStatus(_ status: String, userId: UUID, day: Date) {
        defaults.set(["day": day.timeIntervalSince1970, "status": status], forKey: Self.key(userId))
    }
}
