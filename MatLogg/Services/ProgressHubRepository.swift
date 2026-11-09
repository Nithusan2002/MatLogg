import Foundation

protocol ProgressHubRepository {
    func load(owner: UUID) -> ProgressHubLayout?
    func save(_ layout: ProgressHubLayout, owner: UUID) throws
}

struct UserDefaultsProgressHubRepository: ProgressHubRepository {
    let defaults: UserDefaults

    private struct Record: Codable {
        let version: Int
        let order: [String]
        let visible: [String]
    }

    func load(owner: UUID) -> ProgressHubLayout? {
        guard let data = defaults.data(forKey: ProgressHubStorage.key(owner)),
              let record = try? JSONDecoder().decode(Record.self, from: data),
              (1...2).contains(record.version) else { return nil }
        return ProgressHubLayout(visible: Set(record.visible.compactMap(ProgressHubArea.init(rawValue:))))
    }

    func save(_ layout: ProgressHubLayout, owner: UUID) throws {
        // Keep the existing format readable by earlier versions of the app.
        let record = Record(version: 2, order: ProgressHubLayout.standardOrder.map(\.rawValue),
                            visible: layout.visibleAreas.map(\.rawValue))
        defaults.set(try JSONEncoder().encode(record), forKey: ProgressHubStorage.key(owner))
    }
}
