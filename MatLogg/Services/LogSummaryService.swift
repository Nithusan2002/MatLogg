import Foundation

enum LogSummaryService {
    static let mealOrder: [String] = ["frokost", "lunsj", "middag", "snacks"]
    
    static let mealTitles: [String: String] = [
        "frokost": "Frokost",
        "lunsj": "Lunsj",
        "middag": "Middag",
        "snacks": "Snacks"
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
        let filtered = logs.filter { log in
            if let mealFilter, log.mealType != mealFilter {
                return false
            }
            if searchText.isEmpty {
                return true
            }
            let name = productNameLookup(log.productId).lowercased()
            return name.contains(searchText.lowercased())
        }
        
        let grouped = Dictionary(grouping: filtered, by: { $0.mealType })
        return mealOrder.compactMap { meal in
            guard let mealLogs = grouped[meal], !mealLogs.isEmpty else { return nil }
            return (meal, mealLogs.sorted { $0.loggedTime < $1.loggedTime })
        }
    }
    
    static func limitedLogs(_ logs: [FoodLog], limit: Int) -> [FoodLog] {
        Array(logs.prefix(limit))
    }
}
