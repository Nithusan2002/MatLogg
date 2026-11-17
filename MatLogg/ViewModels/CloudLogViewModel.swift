import Foundation
import Combine

@MainActor
final class CloudLogViewModel: ObservableObject {
    struct Confirmation: Identifiable {
        let id = UUID()
        let action: Action
        let title: String
        let message: String
        let context: UUID
    }
    enum Action { case prepare(CloudLogHistoryChoice), sync, resolve(CloudLogReview, CloudLogResolution), deactivate }
    @Published private(set) var isEnabled = false
    @Published private(set) var mutationRevision = 0
    private var networkAvailable = true
    private var autoPending = false
    @Published private(set) var reviews: [CloudLogReview] = []
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
    @Published private(set) var errorMessage: String?
    @Published var confirmation: Confirmation?
    private var owner: UUID?
    private var context = UUID()
    private var consumedConfirmations: Set<UUID> = []
    private let repository: (any CloudLogRepository)?
    var isAvailable: Bool { repository != nil && owner != nil }

    init(repository: (any CloudLogRepository)?) { self.repository = repository }

    func selectOwner(_ owner: UUID?) async {
        context = UUID()
        consumedConfirmations = []
        let request = context
        self.owner = owner
        confirmation = nil
        reviews = []
        message = nil
        errorMessage = nil
        isBusy = false
        isEnabled = false
        autoPending = false
        await repository?.selectOwner(owner)
        guard context == request, let owner, let repository else { return }
        do {
            let enabled = try await repository.isEnabled(owner: owner)
            guard context == request else { return }
            isEnabled = enabled
            let values = try await repository.reviews(owner: owner)
            guard context == request else { return }
            reviews = values
        } catch { if context == request { errorMessage = Self.message(for: error) } }
    }
    func askToPrepare(_ choice: CloudLogHistoryChoice) {
        guard isAvailable, !isBusy else { return }
        confirmation = Confirmation(action: .prepare(choice), title: "Aktiver matloggsynk?",
            message: choice == .includeLocalHistory
                ? "Matlogger med matvareinformasjon lagres hos Supabase i det lokale testmiljøet. Lokal historikk inkluderes. Nye registreringer, redigeringer og slettinger synkroniseres når appen har nett. Avvik må gjennomgås."
                : "Skyhistorikken lastes ned. Eksisterende lokale avvik beholdes for gjennomgang. Nye registreringer, redigeringer og slettinger synkroniseres til Supabase i testmiljøet når appen har nett.", context: context)
    }
    func askToSync() {
        guard isAvailable, !isBusy else { return }
        confirmation = Confirmation(action: .sync, title: "Synkroniser matlogger?", message: "Usendte matlogger og bekreftede valg sendes til Supabase i testmiljøet. Nye skyendringer lastes ned.", context: context)
    }
    func askToDeactivate() {
        guard isAvailable, isEnabled else { return }
        confirmation = Confirmation(action: .deactivate, title: "Slå av matloggsynk?", message: "Nye overføringer stoppes. Lokale data beholdes. Data som allerede ligger i skyen slettes ikke, og en forespørsel som allerede er sendt kan fullføres. Usendte og senere lokale endringer må gjennomgås ved ny aktivering.", context: context)
    }
    func networkChanged(available: Bool) async {
        networkAvailable = available
        if available { await syncIfEnabled() }
    }
    func syncIfEnabled() async {
        guard isEnabled, networkAvailable, let owner, let repository else { return }
        if isBusy { autoPending = true; return }
        let request = context
        isBusy = true
        autoPending = false
        defer {
            if request == context {
                isBusy = false
                if autoPending { Task { await self.syncIfEnabled() } }
            }
        }
        do {
            try await repository.sync(owner: owner)
            let values = try await repository.reviews(owner: owner)
            guard request == context else { return }
            reviews = values
            errorMessage = nil
            message = "Matloggene er synkronisert."
            mutationRevision += 1
        } catch {
            guard request == context else { return }
            errorMessage = Self.message(for: error)
            mutationRevision += 1
        }
    }
    func askToResolve(_ review: CloudLogReview, choice: CloudLogResolution) {
        guard isAvailable, !isBusy else { return }
        confirmation = Confirmation(action: .resolve(review, choice), title: "Bekreft versjon",
            message: choice == .useCloud
                ? "Skyversjonen brukes på denne iPhonen. Lokale endringer for denne loggen forkastes. Hvis loggen mangler i skyen, fjernes den lokalt."
                : (review.server?.deleted == true && review.local != nil
                    ? "Den lokale versjonen beholdes som en ny logg. Den slettede skyloggen gjenopprettes ikke. Kopien synkroniseres når appen har nett og synk er aktiv."
                    : "Ditt lokale valg lagres som en ny endring og synkroniseres når appen har nett og synk er aktiv. En lokal sletting vil også slette skyloggen."), context: context)
    }
    func confirm(_ confirmed: Confirmation? = nil) async {
        guard let confirmed = confirmed ?? confirmation, confirmed.context == context, !consumedConfirmations.contains(confirmed.id),
              let owner, let repository else { return }
        let action = confirmed.action
        if case .deactivate = action {
            consumedConfirmations.insert(confirmed.id)
            context = UUID()
            let request = context
            confirmation = nil
            isEnabled = false
            autoPending = false
            isBusy = true
            do { try await repository.deactivate(owner: owner) }
            catch {
                if request == context { errorMessage = Self.message(for: error); isBusy = false }
                return
            }
            if request == context { isBusy = false; message = "Matloggsynk er slått av. Lokale data er beholdt." }
            return
        }
        guard !isBusy else { return }
        consumedConfirmations.insert(confirmed.id)
        confirmation = nil
        let request = context
        isBusy = true
        errorMessage = nil
        message = nil
        defer { if context == request { isBusy = false; if autoPending { Task { await self.syncIfEnabled() } } } }
        do {
            switch action {
            case .prepare(let choice): try await repository.prepare(owner: owner, choice: choice)
            case .sync: try await repository.sync(owner: owner)
            case .resolve(let review, let choice): try await repository.resolve(review, choice: choice, owner: owner)
            case .deactivate: break
            }
            guard context == request else { return }
            let enabled = try await repository.isEnabled(owner: owner)
            let values = try await repository.reviews(owner: owner)
            guard context == request else { return }
            reviews = values
            isEnabled = enabled
            mutationRevision += 1
            switch action {
            case .prepare: message = "Matloggsynk er aktivert. Gjennomgå eventuelle avvik."; autoPending = true
            case .sync: message = "Synkroniseringen er fullført."
            case .resolve: message = "Valget er lagret på denne iPhonen."
            case .deactivate: break
            }
        } catch {
            guard context == request else { return }
            errorMessage = Self.message(for: error)
            // Refresh confirmation snapshots after a rejected/stale choice.
            if let values = try? await repository.reviews(owner: owner), context == request { reviews = values }
        }
    }
    private static func message(for error: any Error) -> String {
        switch error {
        case CloudLogError.historyReviewRequired: "Loggen er endret siden du åpnet valget. Gjennomgå de oppdaterte versjonene."
        case CloudLogError.bootstrapRequired: "Velg historikk og klargjør først."
        case CloudLogError.historyChoiceMismatch: "En avbrutt klargjøring må fortsette med det samme historikkvalget."
        case CloudLogError.historyEpochMismatch: "Skyhistorikken er endret. Klargjør historikken på nytt før du fortsetter."
        case CloudLogError.snapshotExpired: "Nedlastingen utløp. Klargjør historikken på nytt."
        case CloudLogError.ownerChanged: "Kontoen eller en pågående operasjon er endret. Åpne siden på nytt."
        default: "Kunne ikke fullføre. Kontroller nettverket og at testkontoen har tilgang til synk. Lokale data er beholdt."
        }
    }
}
