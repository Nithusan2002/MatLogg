import Foundation
import Combine

@MainActor
final class HealthIntegrationViewModel: ObservableObject {
    @Published var choices = HealthIntegrationSettings()
    @Published private(set) var settings = HealthIntegrationSettings()
    @Published private(set) var records: [HealthExportRecord] = []
    @Published private(set) var messages: [HealthDataKind: String] = [:]
    @Published private(set) var importMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isBusy = false
    @Published private(set) var completionMessage: String?
    private let repository: any HealthIntegrationRepository
    private var refreshRequested = false
    private var owner: UUID?
    private var contextID = UUID()
    var isAvailable: Bool { repository.isAvailable }

    init(repository: any HealthIntegrationRepository) { self.repository = repository }
    func selectOwner(_ owner: UUID?) {
        guard self.owner != owner else { return }
        refreshRequested = false
        contextID = UUID()
        self.owner = owner
        repository.selectOwner(owner)
        settings = HealthIntegrationSettings()
        choices = settings
        records = []
        messages = [:]
        importMessage = nil
        errorMessage = nil
        completionMessage = nil
        isBusy = false
        reload(resetChoices: true)
    }
    private func reload(resetChoices: Bool = false) {
        guard let owner else { return }
        do {
            let status = try repository.status(owner: owner)
            settings = status.settings
            if resetChoices { choices = settings }
            records = status.records
            messages = status.messages
            importMessage = status.importMessage
        } catch { errorMessage = "Kunne ikke lese innstillingene for Apple Helse." }
    }
    func refresh() async {
        guard let owner else { return }
        if isBusy { refreshRequested = true; return }
        await perform { try await self.repository.refresh(owner: owner) }
    }
    func connect() async {
        guard let owner, choices.shareNutrition || choices.readWeight || choices.shareWeight, !isBusy else { return }
        let selected = choices
        await perform(resetChoices: true) { try await self.repository.connect(owner: owner, choices: selected) }
    }
    func disconnect() {
        guard let owner, !isBusy else { return }
        do { try repository.disconnect(owner: owner); errorMessage = nil; reload(resetChoices: true) }
        catch { errorMessage = "Overføring er stoppet, men oppryddingen kunne ikke fullføres. Prøv igjen." }
    }
    func deleteExports() async {
        guard let owner, !isBusy else { return }
        await perform(resetChoices: true) {
            try await self.repository.deleteExports(owner: owner)
            self.completionMessage = "Data MatLogg har delt med Helse er slettet."
        }
    }
    private func perform(resetChoices: Bool = false, _ operation: () async throws -> Void) async {
        let context = contextID
        isBusy = true
        errorMessage = nil
        completionMessage = nil
        defer {
            if contextID == context {
                isBusy = false
                reload(resetChoices: resetChoices)
                if refreshRequested {
                    refreshRequested = false
                    Task { await self.refresh() }
                }
            }
        }
        do { try await operation() }
        catch HealthIntegrationError.staleContext { return }
        catch {
            guard contextID == context else { return }
            errorMessage = "Handlingen i Apple Helse kunne ikke fullføres. Kontroller tilgangene i Helse og prøv igjen."
        }
    }
    func exportStatus(kinds: [HealthDataKind]) -> String {
        let selected = records.filter { kinds.contains($0.kind) }
        if let message = kinds.compactMap({ messages[$0] }).first { return message }
        if selected.contains(where: { $0.pending }) { return "Overføring til Helse venter." }
        guard let last = selected.compactMap(\.lastSuccess).max() else { return "Ingen registreringer overført ennå." }
        return "Sist overført: \(last.formatted(date: .abbreviated, time: .shortened))"
    }
}
