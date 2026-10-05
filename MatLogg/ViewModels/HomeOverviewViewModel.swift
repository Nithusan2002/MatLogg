import Combine
import Foundation
import SwiftUI

private struct FoodLogRepositoryKey: EnvironmentKey {
    static let defaultValue: (any FoodLogRepository)? = nil
}

extension EnvironmentValues {
    var foodLogRepository: (any FoodLogRepository)? {
        get { self[FoodLogRepositoryKey.self] }
        set { self[FoodLogRepositoryKey.self] = newValue }
    }
}

struct HomeOverview {
    let summary: DailySummary?
    let productNames: [UUID: String]
    let logsByMeal: [String: [FoodLog]]
    let mealTotals: [String: NutritionBreakdown]

    init(summary: DailySummary?, productNames: [UUID: String], logsByMeal: [String: [FoodLog]]) {
        self.summary = summary
        self.productNames = productNames
        self.logsByMeal = logsByMeal
        mealTotals = logsByMeal.mapValues { NutritionCalculator.totals(for: $0) }
    }
    static let empty = HomeOverview(summary: nil, productNames: [:], logsByMeal: [:])
}

/// Owns loaded presentation data and observes only inputs used by the home content.
@MainActor
final class HomeOverviewViewModel: ObservableObject {
    @Published private(set) var overview = HomeOverview.empty
    @Published private(set) var loggingStreak: Int?
    @Published private(set) var isLoading = true
    @Published private(set) var products: [UUID: Product] = [:]
    @Published private(set) var errorMessage: String?
    private let repository: any FoodLogRepository
    private var requestID = UUID()
    private var subscriptions = Set<AnyCancellable>()
    private var owner: UUID?
    private var day: Date?

    init(repository: any FoodLogRepository) { self.repository = repository }

    convenience init(repository: any FoodLogRepository, appState: AppState, auth: AuthViewModel,
         logs: LogViewModel, savedMeals: SavedMealsViewModel,
         health: HealthProfileViewModel, preferences: PreferencesViewModel) {
        self.init(repository: repository)
        observe(appState.$logSelectedDate.removeDuplicates())
        auth.$currentUser.map { $0?.id }.removeDuplicates().dropFirst()
            .sink { [weak self] _ in self?.reset() }.store(in: &subscriptions)
        observe(auth.$currentUser.map { $0?.fullName }.removeDuplicates())
        observe(logs.$mutationRevision.removeDuplicates())
        observe(savedMeals.$mutationRevision.removeDuplicates())
        observe(health.$currentGoal)
        observe(health.$personalDetails)
        observe(preferences.$showGoalStatusOnHome.removeDuplicates())
    }

    func shouldShowEmptyDay(userId: UUID?, date: Date) -> Bool {
        guard let userId, owner == userId,
              day == Calendar.current.startOfDay(for: date),
              !isLoading, errorMessage == nil,
              let summary = overview.summary else { return false }
        return summary.logs.isEmpty
    }

    func reset() {
        requestID = UUID()
        loggingStreak = nil
        owner = nil
        day = nil
        overview = .empty
        products = [:]
        errorMessage = nil
        isLoading = true
    }

    private func observe<P: Publisher>(_ publisher: P) where P.Failure == Never {
        publisher.dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &subscriptions)
    }

    func load(userId: UUID?, date: Date, now: Date = Date(), calendar: Calendar = .current) async {
        let timing = PerformanceSignposts.begin("Home.Load")
        defer { PerformanceSignposts.end(timing) }
        let selectedDay = Calendar.current.startOfDay(for: date)
        if owner != userId { loggingStreak = nil }
        if owner != userId || day != selectedDay {
            overview = .empty
            products = [:]
        }
        owner = userId
        day = selectedDay
        let request = UUID()
        requestID = request
        isLoading = true
        errorMessage = nil
        defer { if requestID == request { isLoading = false } }
        guard let userId else { return }
        do {
            let summariesTiming = PerformanceSignposts.begin("Home.Summaries")
            let summaries = try await { () async throws -> [DailySummary] in
                defer { PerformanceSignposts.end(summariesTiming) }
                return try await repository.loadSummaries(userId: userId, dates: [selectedDay])
            }()
            guard let summary = summaries.first else { throw DatabaseServiceError.unavailable }
            // A streak read failure must not hide the selected day's overview or report a false zero.
            let loggingDates = try? await repository.loadLoggingDates(userId: userId)
            let productsTiming = PerformanceSignposts.begin("Home.Products")
            let products = await repository.getProducts(Set(summary.logs.map(\.productId)))
            PerformanceSignposts.end(productsTiming)
            guard requestID == request, !Task.isCancelled else { return }
            loggingStreak = loggingDates.map { LoggingStreakCalculator.count(dates: $0, now: now, calendar: calendar) }
            self.products = products
            overview = PerformanceSignposts.measure("Home.PrepareOverview") {
                HomeOverview(summary: summary, productNames: products.mapValues(\.name),
                             logsByMeal: summary.logsByMeal)
            }
        } catch {
            guard requestID == request, !Task.isCancelled else { return }
            loggingStreak = nil
            errorMessage = "Kunne ikke hente oversikten. Prøv igjen."
        }
    }
}
