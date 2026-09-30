import Foundation
import Combine

@MainActor
final class WaterViewModel: ObservableObject {
    @Published private(set) var mutationRevision = 0
    @Published private(set) var glasses: [WaterGlass] = []
    @Published private(set) var isBusy = false
    @Published private(set) var isLoaded = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canUndo = false
    private let repository: any WaterRepository
    private var contextID = UUID()
    private var owner: UUID?
    private var date = Date()
    private var lastAddedID: UUID?

    init(repository: any WaterRepository) { self.repository = repository }

    func load(userId: UUID?, date: Date) async {
        let request = UUID()
        contextID = request
        owner = userId
        self.date = date
        glasses = []
        isLoaded = false
        errorMessage = nil
        lastAddedID = nil
        canUndo = false
        guard let userId else { return }
        do {
            let all = try await repository.getWaterGlasses(userId: userId)
            guard contextID == request else { return }
            glasses = all.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            isLoaded = true
        } catch {
            guard contextID == request else { return }
            errorMessage = "Kunne ikke hente vannloggen. Prøv igjen."
        }
    }

    func add() async {
        guard !isBusy, isLoaded, let owner else { return }
        isBusy = true
        defer { isBusy = false }
        let request = contextID
        let glass = WaterGlass(userId: owner, date: date)
        do {
            try await repository.saveWaterGlass(glass)
            mutationRevision += 1
            guard request == contextID else {
                await load(userId: self.owner, date: self.date)
                return
            }
            glasses.append(glass)
            lastAddedID = glass.id
            canUndo = true
            errorMessage = nil
        } catch {
            guard request == contextID else { return }
            errorMessage = "Glasset ble ikke lagret. Prøv igjen."
        }
    }

    func remove(undo: Bool = false) async {
        guard !isBusy, isLoaded, let owner,
              let id = undo ? lastAddedID : glasses.last?.id else { return }
        isBusy = true
        defer { isBusy = false }
        let request = contextID
        do {
            try await repository.deleteWaterGlass(id, userId: owner)
            mutationRevision += 1
            guard request == contextID else {
                await load(userId: self.owner, date: self.date)
                return
            }
            glasses.removeAll { $0.id == id }
            canUndo = false
            lastAddedID = nil
            errorMessage = nil
        } catch {
            guard request == contextID else { return }
            errorMessage = "Kunne ikke fjerne glasset. Prøv igjen."
        }
    }
}
