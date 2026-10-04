import Combine

/// The tab container observes navigation and overlays, not logging or sync work.
@MainActor
final class HomeNavigationViewModel: ObservableObject {
    @Published private(set) var selectedTab: AppTab = .home
    @Published private(set) var isOnboarding = false
    @Published private(set) var savedMealReceipt: SavedMealReceipt?

    init(appState: AppState, auth: AuthViewModel, savedMeals: SavedMealsViewModel) {
        appState.$selectedTab.removeDuplicates().assign(to: &$selectedTab)
        auth.$isOnboarding.removeDuplicates().assign(to: &$isOnboarding)
        savedMeals.$receipt.removeDuplicates().assign(to: &$savedMealReceipt)
    }
}
