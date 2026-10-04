import Foundation
import Combine

@MainActor
final class FoodSearchViewModel: ObservableObject {
    enum Phase { case local, searching, complete, offline, failure }

    @Published private(set) var query = ""
    @Published private(set) var results: [Product] = []
    @Published private(set) var recent: [Product] = []
    @Published private(set) var favorites: [Product] = []
    @Published private(set) var suggestions: [Product] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingCatalog = false {
        didSet {
            catalogFeedback.update(isActive: isLoadingCatalog) { [weak self] in self?.showsCatalogFeedback = $0 }
        }
    }
    @Published private(set) var showsCatalogFeedback = false
    @Published private(set) var showsSearchFeedback = false
    private let catalogFeedback = DelayedActivity()
    private let searchFeedback = DelayedActivity()
    @Published private(set) var phase: Phase = .local {
        didSet {
            searchFeedback.update(isActive: phase == .searching) { [weak self] in self?.showsSearchFeedback = $0 }
        }
    }
    @Published private(set) var loadError: String?
    @Published private(set) var searchError: String?
    @Published private(set) var selectionError: String?
    @Published private(set) var isPreparing = false
    @Published private(set) var preparingProductID: UUID?
    @Published var selectedProduct: Product?

    private let repository: any FoodSearchRepository
    private var library: [Product] = []
    private var remoteProducts: [Product] = []
    private var pendingManualProduct: Product?
    private var owner: UUID?
    private var loadID = UUID()
    private var searchID = UUID()
    private var selectionID = UUID()
    private var preparationIndicatorTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var resultsID = UUID()
    private let searchIndex = FoodSearchIndex()

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(repository: any FoodSearchRepository) { self.repository = repository }

    func load(owner: UUID?) async {
        let timing = PerformanceSignposts.begin("Search.Load")
        defer { PerformanceSignposts.end(timing) }
        let localTiming = PerformanceSignposts.begin("Search.FirstLocal")
        var localEnded = false
        defer { if !localEnded { PerformanceSignposts.end(localTiming) } }
        let request = UUID()
        if self.owner != owner {
            reset(owner: owner)
        }
        loadID = request
        loadError = nil
        isLoadingCatalog = true
        do {
            let loaded = try await repository.loadLibrary(owner: owner) { local in
                guard self.loadID == request, self.owner == owner, !Task.isCancelled else { return }
                self.apply(local)
                self.isLoading = false
                if !localEnded {
                    PerformanceSignposts.end(localTiming)
                    localEnded = true
                }
            }
            guard loadID == request, self.owner == owner, !Task.isCancelled else { return }
            apply(loaded)
            await resultsTask?.value
            guard loadID == request, self.owner == owner, !Task.isCancelled else { return }
        } catch {
            guard loadID == request, self.owner == owner, !Task.isCancelled else { return }
            loadError = "Kunne ikke hente lagrede matvarer. Prøv igjen."
        }
        isLoading = false
        isLoadingCatalog = false
    }

    private func apply(_ loaded: FoodSearchLibrary) {
        library = loaded.products
        recent = loaded.recent
        favorites = loaded.favorites
        suggestions = loaded.suggestions
        updateResults()
    }

    func reset(owner: UUID?) {
        loadID = UUID()
        resultsID = UUID()
        resultsTask?.cancel()
        cancelSearch()
        self.owner = owner
        selectionID = UUID()
        query = ""
        library = []; remoteProducts = []; results = []
        recent = []; favorites = []; suggestions = []
        selectedProduct = nil
        pendingManualProduct = nil
        selectionError = nil
        preparationIndicatorTask?.cancel()
        preparationIndicatorTask = nil
        preparingProductID = nil
        isPreparing = false
        loadError = nil
        isLoading = true
        isLoadingCatalog = false
    }

    func setQuery(_ value: String) {
        let limited = String(value.prefix(80))
        guard query != limited else { return }
        cancelSearch()
        query = limited
        remoteProducts = []
        selectionError = nil
        updateResults()
    }

    func search() {
        guard hasQuery, !isLoading else { return }
        cancelSearch()
        let request = UUID()
        searchID = request
        let submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedOwner = owner
        phase = .searching
        searchTask = Task { [weak self] in
            let timing = PerformanceSignposts.begin("Search.RemoteToState")
            defer { PerformanceSignposts.end(timing) }
            guard let self else { return }
            do {
                let products = try await repository.searchRemote(query: submittedQuery, owner: submittedOwner)
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                remoteProducts = products
                updateResults()
                await resultsTask?.value
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                phase = .complete
            } catch {
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                // Local matches stay available even when the external service fails.
                await resultsTask?.value
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                phase = results.isEmpty ? .failure : .offline
                searchError = Self.message(for: error)
            }
        }
    }

    func cancelSearch() {
        searchID = UUID()
        searchTask?.cancel()
        searchTask = nil
        phase = .local
        searchError = nil
    }

    func suspend() {
        searchID = UUID()
        searchTask?.cancel()
        searchTask = nil
        if phase == .searching {
            phase = .local
            remoteProducts = []
            updateResults()
        }
        selectionID = UUID()
        preparationIndicatorTask?.cancel()
        preparationIndicatorTask = nil
        preparingProductID = nil
        isPreparing = false
    }

    func saveManual(_ product: Product) async throws {
        guard let owner else { throw DatabaseServiceError.unavailable }
        try await repository.saveManual(product, owner: owner)
        guard self.owner == owner, !Task.isCancelled else { throw CancellationError() }
    }

    func manualProductSaved(_ product: Product) { pendingManualProduct = product }

    func finishManualCreation() {
        selectedProduct = pendingManualProduct
        pendingManualProduct = nil
    }

    func open(_ product: Product) async {
        guard !isPreparing, selectedProduct == nil else { return }
        guard let owner else {
            selectionError = "Åpne en lokal profil for å loggføre mat."
            return
        }
        let request = UUID()
        selectionID = request
        isPreparing = true
        selectionError = nil
        preparationIndicatorTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(180)) }
            catch { return }
            guard let self, self.selectionID == request, !Task.isCancelled else { return }
            self.preparingProductID = product.id
        }
        defer {
            if selectionID == request {
                preparationIndicatorTask?.cancel()
                preparationIndicatorTask = nil
                preparingProductID = nil
                isPreparing = false
            }
        }
        do {
            try await repository.prepare(product, owner: owner)
            guard selectionID == request, self.owner == owner, !Task.isCancelled else { return }
            selectedProduct = product
        } catch {
            guard selectionID == request, self.owner == owner, !Task.isCancelled else { return }
            selectionError = "Kunne ikke åpne matvaren. Prøv igjen."
        }
    }

    private func updateResults() {
        resultsTask?.cancel()
        let request = UUID()
        resultsID = request
        guard hasQuery else { results = []; return }
        let query = query
        let library = library
        let remote = remoteProducts
        let index = searchIndex
        resultsTask = Task { [weak self] in
            let timing = PerformanceSignposts.begin("Search.ResultsToState")
            defer { PerformanceSignposts.end(timing) }
            guard let computed = try? await index.results(library: library, remote: remote, query: query), let self, resultsID == request, !Task.isCancelled else { return }
            results = computed
        }
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIService.APIError, case .rateLimited = apiError {
            return apiError.localizedDescription
        }
        return "Kunne ikke hente nye produkter fra Open Food Facts. Lagrede matvarer kan fortsatt brukes."
    }
}
