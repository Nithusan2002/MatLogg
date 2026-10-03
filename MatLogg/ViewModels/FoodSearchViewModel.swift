import Foundation
import Combine

@MainActor
final class FoodSearchViewModel: ObservableObject {
    enum Phase { case local, searching, complete, offline, failure }

    @Published private(set) var query = ""
    @Published private(set) var results: [Product] = []
    @Published private(set) var recent: [Product] = []
    @Published private(set) var recentFoods: [RecentFood] = []
    @Published private(set) var isRepeating = false
    @Published private(set) var favorites: [Product] = []
    @Published private(set) var suggestions: [Product] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingCatalog = false
    @Published private(set) var phase: Phase = .local
    @Published private(set) var loadError: String?
    @Published private(set) var searchError: String?
    @Published private(set) var selectionError: String?
    @Published private(set) var isPreparing = false
    @Published var selectedProduct: Product?

    private let repository: any FoodSearchRepository
    private var library: [Product] = []
    private var remoteProducts: [Product] = []
    private var pendingManualProduct: Product?
    private var owner: UUID?
    private var loadID = UUID()
    private var searchID = UUID()
    private var selectionID = UUID()
    private var searchTask: Task<Void, Never>?
    private var repeatID = UUID()

    var hasQuery: Bool { !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    init(repository: any FoodSearchRepository) { self.repository = repository }

    func load(owner: UUID?) async {
        let request = UUID()
        if self.owner != owner {
            reset(owner: owner)
        }
        loadID = request
        loadError = nil
        isLoadingCatalog = true
        do {
            let local = try await repository.loadLocalLibrary(owner: owner)
            guard loadID == request, self.owner == owner, !Task.isCancelled else { return }
            apply(local)
            isLoading = false
            let loaded = try await repository.loadLibrary(owner: owner)
            guard loadID == request, self.owner == owner, !Task.isCancelled else { return }
            apply(loaded)
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
        recentFoods = loaded.recentFoods
        favorites = loaded.favorites
        suggestions = loaded.suggestions
        updateResults()
    }

    func reset(owner: UUID?) {
        loadID = UUID()
        cancelSearch()
        self.owner = owner
        selectionID = UUID()
        query = ""
        library = []; remoteProducts = []; results = []
        recent = []; favorites = []; suggestions = []
        recentFoods = []
        invalidateRepeatPresentation()
        selectedProduct = nil
        pendingManualProduct = nil
        selectionError = nil
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
            guard let self else { return }
            do {
                let products = try await repository.searchRemote(query: submittedQuery, owner: submittedOwner)
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                remoteProducts = products
                updateResults()
                phase = .complete
            } catch {
                guard searchID == request, owner == submittedOwner, !Task.isCancelled else { return }
                // Local matches stay available even when the external service fails.
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
        invalidateRepeatPresentation()
        searchID = UUID()
        searchTask?.cancel()
        searchTask = nil
        if phase == .searching {
            phase = .local
            remoteProducts = []
            updateResults()
        }
        selectionID = UUID()
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
        guard !isPreparing, !isRepeating else { return }
        guard let owner else {
            selectionError = "Åpne en lokal profil for å loggføre mat."
            return
        }
        let request = UUID()
        selectionID = request
        isPreparing = true
        selectionError = nil
        do {
            try await repository.prepare(product, owner: owner)
            guard selectionID == request, self.owner == owner, !Task.isCancelled else { return }
            selectedProduct = product
        } catch {
            guard selectionID == request, self.owner == owner, !Task.isCancelled else { return }
            selectionError = "Kunne ikke åpne matvaren. Prøv igjen."
        }
        if selectionID == request { isPreparing = false }
    }

    func invalidateRepeatPresentation() {
        repeatID = UUID()
        selectionError = nil
    }

    func logAgain(_ food: RecentFood, mealType: String, date: Date) async -> (Product, FoodLog)? {
        guard !isRepeating, !isPreparing, let owner, food.log.userId == owner else { return nil }
        let request = UUID()
        repeatID = request
        isRepeating = true
        selectionError = nil
        defer { isRepeating = false }
        do {
            let outcome = try await repository.logAgain(food, owner: owner, mealType: mealType, date: date)
            guard repeatID == request, self.owner == owner, !Task.isCancelled else { return nil }
            switch outcome {
            case .logged(let product, let log): return (product, log)
            case .review(let product):
                selectedProduct = product
                return nil
            }
        } catch {
            guard repeatID == request, self.owner == owner, !Task.isCancelled else { return nil }
            selectionError = "Kunne ikke lagre på enheten. Prøv igjen."
            return nil
        }
    }

    private func updateResults() {
        guard hasQuery else { results = []; return }
        let local = library.filter { FoodSearchMatcher.matches(query: query, name: $0.name, brand: $0.brand) }
        results = FoodSearchMatcher.sorted(FoodSearchMatcher.unique(local + remoteProducts), query: query)
    }

    private static func message(for error: Error) -> String {
        if let apiError = error as? APIService.APIError, case .rateLimited = apiError {
            return apiError.localizedDescription
        }
        return "Kunne ikke hente nye produkter fra Open Food Facts. Lagrede matvarer kan fortsatt brukes."
    }
}
