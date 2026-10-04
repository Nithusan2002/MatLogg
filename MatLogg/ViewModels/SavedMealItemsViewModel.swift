import Combine
import Foundation

/// Caches ordering and row text independently of amount editing and photo state.
@MainActor
final class SavedMealItemsViewModel: ObservableObject {
    @Published private(set) var sortedItems: [SavedMealItem]
    @Published private(set) var visibleItems: [SavedMealItem]
    @Published private(set) var subtitle: String
    @Published var removed = Set<UUID>() {
        didSet { if oldValue != removed { visibleItems = sortedItems.filter { !removed.contains($0.id) } } }
    }
    private var meal: SavedMeal

    init(meal: SavedMeal) {
        self.meal = meal
        let items = meal.items.sorted { $0.sortIndex < $1.sortIndex }
        sortedItems = items
        visibleItems = items
        subtitle = Self.subtitle(items)
    }

    func update(_ meal: SavedMeal) {
        guard meal.items != self.meal.items else { self.meal = meal; return }
        self.meal = meal
        let items = meal.items.sorted { $0.sortIndex < $1.sortIndex }
        sortedItems = items
        visibleItems = items.filter { !removed.contains($0.id) }
        subtitle = Self.subtitle(items)
    }

    private static func subtitle(_ items: [SavedMealItem]) -> String {
        let names = items.prefix(3).map(\.productName)
        let suffix = items.count > 3 ? " + \(items.count - 3) til" : ""
        let itemCount = items.count == 1 ? "1 vare" : "\(items.count) varer"
        return "\(itemCount) · \(names.joined(separator: ", "))\(suffix)"
    }
}
