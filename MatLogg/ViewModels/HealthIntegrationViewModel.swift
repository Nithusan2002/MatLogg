import Foundation
import Combine

@MainActor
final class HealthIntegrationViewModel: ObservableObject {
    @Published var choices = HealthIntegrationSettings()
    @Published private(set) var settings = HealthIntegrationSettings()
    @Published private(set) var records: [HealthExportRecord] = []
    @Published private(set) var messages: [HealthDataKind: String] = [:]
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
        errorMessage = nil
        completionMessage = nil
        isBusy = false
        Task { await reload(resetChoices: true) }
    }
    private func reload(resetChoices: Bool = false) async {
        let context = contextID
        guard let owner else { return }
        do {
            let status = try await repository.status(owner: owner)
            guard contextID == context else { return }
            settings = status.settings
            if resetChoices { choices = settings }
            records = status.records
            messages = status.messages
        } catch {
            guard contextID == context else { return }
            errorMessage = "Kunne ikke lese innstillingene for Apple Helse."
        }
    }
    func refresh() async {
        guard let owner else { return }
        if isBusy { refreshRequested = true; return }
        await perform { try await self.repository.refresh(owner: owner) }
    }
    func connect() async {
        guard let owner, choices.shareNutrition || choices.shareWeight, !isBusy else { return }
        let selected = choices
        await perform(resetChoices: true) { try await self.repository.connect(owner: owner, choices: selected) }
    }
    func disconnect() async {
        guard let owner, !isBusy else { return }
        await perform(resetChoices: true) { try await self.repository.disconnect(owner: owner) }
    }
    func deleteExports() async {
        guard let owner, !isBusy else { return }
        await perform(resetChoices: true) {
            try await self.repository.deleteExports(owner: owner)
            self.completionMessage = "Data MatLogg har delt med Helse er slettet."
        }
    }
    private func perform(resetChoices: Bool = false, _ operation: () async throws -> Void) async {
        contextID = UUID()
        let context = contextID
        isBusy = true
        errorMessage = nil
        completionMessage = nil
        do { try await operation() }
        catch HealthIntegrationError.staleContext {}
        catch {
            guard contextID == context else { return }
            errorMessage = "Handlingen i Apple Helse kunne ikke fullføres. Kontroller tilgangene i Helse og prøv igjen."
        }
        guard contextID == context else { return }
        await reload(resetChoices: resetChoices)
        guard contextID == context else { return }
        isBusy = false
        if refreshRequested {
            refreshRequested = false
            Task { await self.refresh() }
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
