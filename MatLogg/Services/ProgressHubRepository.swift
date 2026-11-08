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
        var order: [ProgressHubArea] = []
        for raw in record.order {
            if let area = ProgressHubArea(rawValue: raw), !order.contains(area) { order.append(area) }
        }
        order += ProgressHubArea.allCases.filter { !order.contains($0) }
        if record.version == 1 && order == [.nutrition, .weight, .steps] {
            order = [.nutrition, .steps, .weight]
        }
        return ProgressHubLayout(order: order, visible: Set(record.visible.compactMap(ProgressHubArea.init(rawValue:))))
    }

    func save(_ layout: ProgressHubLayout, owner: UUID) throws {
        let record = Record(version: 2, order: layout.order.map(\.rawValue),
                            visible: layout.order.filter { layout.visible.contains($0) }.map(\.rawValue))
        defaults.set(try JSONEncoder().encode(record), forKey: ProgressHubStorage.key(owner))
    }
}
