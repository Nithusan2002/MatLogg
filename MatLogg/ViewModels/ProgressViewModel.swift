import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published private(set) var summaries: [DailySummary] = []
    @Published private(set) var metrics = ProgressMetrics(summaries: [])
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private let repository: any FoodLogRepository
    private var requestID = UUID()
    private var owner: UUID?

    init(repository: any FoodLogRepository) { self.repository = repository }

    func reset() {
        requestID = UUID()
        owner = nil
        summaries = []
        metrics = ProgressMetrics(summaries: [])
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = (-6...0).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        do {
            let loaded = try await repository.loadSummaries(userId: userId, dates: dates)
            guard requestID == request, !Task.isCancelled else { return }
            summaries = loaded
            metrics = ProgressMetrics(summaries: loaded)
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            errorMessage = "Kunne ikke hente ukesoversikten. Prøv igjen."
        }
    }
}
