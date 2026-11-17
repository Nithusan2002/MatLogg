import Foundation

nonisolated struct CloudLogConnection: Codable, Sendable {
    let owner: UUID
    var enabled: Bool
    let device: UUID
}

nonisolated extension Notification.Name {
    static let cloudLogNeedsSync = Notification.Name("MatLogg.cloudLogNeedsSync")
}
