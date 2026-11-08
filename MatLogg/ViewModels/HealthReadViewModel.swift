import Foundation
import Combine

typealias StepCountViewModel = HealthReadViewModel<StepCountSnapshot>
typealias HealthWeightViewModel = HealthReadViewModel<HealthWeightSnapshot>

@MainActor
final class HealthReadViewModel<Snapshot: HealthReadSnapshot>: ObservableObject {
    enum State: Equatable {
        case notConnected, loading, noData, failed, unavailable, demo
        case loaded(Snapshot)
    }

    @Published private(set) var state: State = .notConnected
    @Published private(set) var isEnabled = false
    @Published private(set) var owner: UUID?
    @Published private(set) var connectionError: String?
    @Published private var authorizationID: UUID?
    private var isVisible = false
    private var range: DateInterval?
    private var readID = UUID()
    private let repository: any HealthReadRepository<Snapshot>
    private let connections: any HealthConnectionRepository
    private let now: () -> Date

    init(repository: any HealthReadRepository<Snapshot>, connections: any HealthConnectionRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.connections = connections
        self.now = now
    }

    var availability: HealthDataAvailability { repository.availability }
    var isAuthorizing: Bool { authorizationID != nil }

    func activate(owner: UUID?) {
        guard self.owner != owner else { return }
        reset()
        self.owner = owner
        if let owner { isEnabled = connections.isEnabled(owner: owner) }
    }

    func update(owner: UUID?, isVisible: Bool, range: DateInterval) async {
        guard !Task.isCancelled else { return }
        activate(owner: owner)
        if !isVisible { suspend(); return }
        self.isVisible = isVisible
        self.range = range
        await refresh()
    }

    func snapshot(for range: DateInterval) -> Snapshot? {
        guard case .loaded(let snapshot) = state, snapshot.range == range else { return nil }
        return snapshot
    }

    func refresh() async {
        guard !Task.isCancelled, owner != nil, isVisible, !isAuthorizing, let range else { return }
        readID = UUID()
        switch availability {
        case .unavailable: state = .unavailable; return
        case .demo: state = .demo; return
        case .available: break
        }
        guard isEnabled else { state = .notConnected; return }
        let request = readID
        state = .loading
        do {
            let snapshot = try await repository.read(in: range, through: now())
            guard readID == request, !Task.isCancelled else { return }
            state = snapshot.hasData ? .loaded(snapshot) : .noData
        } catch {
            guard readID == request, !Task.isCancelled else { return }
            state = .failed
        }
    }

    func connect() async {
        guard let owner, !Task.isCancelled, !isEnabled, !isAuthorizing, availability == .available else { return }
        let request = UUID()
        authorizationID = request
        connectionError = nil
        do {
            try await repository.requestAccess()
            guard authorizationID == request, self.owner == owner else { return }
            try Task.checkCancellation()
            try connections.setEnabled(true, owner: owner)
            isEnabled = true
            authorizationID = nil
            await refresh()
        } catch {
            guard authorizationID == request else { return }
            authorizationID = nil
            if !Task.isCancelled { connectionError = "Kunne ikke slå på henting. Prøv igjen." }
        }
    }

    func disconnect() {
        guard let owner else { return }
        authorizationID = nil
        connectionError = nil
        do {
            try connections.setEnabled(false, owner: owner)
            readID = UUID()
            isEnabled = false
            state = .notConnected
        } catch {
            connectionError = "Kunne ikke slå av henting. Prøv igjen."
        }
    }

    func suspend() {
        readID = UUID()
        isVisible = false
        range = nil
        state = .notConnected
    }

    func reset() {
        suspend()
        authorizationID = nil
        connectionError = nil
        owner = nil
        isEnabled = false
    }
}
