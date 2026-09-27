import Combine
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    @Published private(set) var restorationCount = 0

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "app.matlogg.network-monitor")
    private var previousWasSatisfied: Bool?

    init(monitor: NWPathMonitor = NWPathMonitor()) {
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.accept(isSatisfied: path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    private func accept(isSatisfied: Bool) {
        if previousWasSatisfied == false, isSatisfied {
            restorationCount += 1
        }
        previousWasSatisfied = isSatisfied
    }
}
