import Foundation
import Combine

@MainActor
final class ScanHistoryViewModel: ObservableObject {
    @Published private(set) var scans: [ScanHistory] = []
    @Published private(set) var products: [UUID: Product] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private let repository: any ScanHistoryRepository
    private var requestID = UUID()
    private var owner: UUID?

    init(repository: any ScanHistoryRepository) { self.repository = repository }

    func reset() {
        requestID = UUID()
        owner = nil
        scans = []
        products = [:]
        isLoading = true
        errorMessage = nil
    }

    func load(userId: UUID?) async {
        if owner != userId { reset() }
        owner = userId
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        defer { if requestID == request { isLoading = false } }
        guard let userId else { return }
        do {
            let result = try await repository.loadScanHistory(userId: userId)
            guard requestID == request, !Task.isCancelled else { return }
            scans = result.scans
            products = result.products
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke hente skannehistorikken. Prøv igjen."
        }
    }
}
