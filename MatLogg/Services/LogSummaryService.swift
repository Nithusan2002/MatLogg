import Foundation

enum LogSummaryService {
    static let mealOrder: [String] = ["frokost", "lunsj", "middag", "snacks"]
    
    static let mealTitles: [String: String] = [
        "frokost": "Frokost",
        "lunsj": "Lunsj",
        "middag": "Middag",
        "snacks": "Kveldsmat"
    ]
    
    static func title(for mealType: String) -> String {
        mealTitles[mealType, default: mealType.capitalized]
    }
    
    static func groupedLogs(
        logs: [FoodLog],
        searchText: String = "",
        mealFilter: String? = nil,
        productNameLookup: (UUID) -> String
    ) -> [(mealType: String, logs: [FoodLog])] {
        let query = searchText.lowercased()
        let filtered = logs.filter { log in
            if let mealFilter, log.mealType != mealFilter {
                return false
            }
            if query.isEmpty {
                return true
            }
            let name = productNameLookup(log.productId).lowercased()
            return name.contains(query)
        }
        
        let grouped = Dictionary(grouping: filtered, by: { $0.mealType })
        return mealOrder.compactMap { meal in
            guard let mealLogs = grouped[meal], !mealLogs.isEmpty else { return nil }
            return (meal, mealLogs.sorted { $0.loggedTime < $1.loggedTime })
        }
    }
    
    static func limitedLogs(_ logs: [FoodLog], limit: Int) -> [FoodLog] {
        guard limit > 0 else { return [] }
        return Array(logs.prefix(limit))
    }
}
