import Foundation

/// Visual groups only: never used to infer nutrients, units or source verification.
nonisolated enum FoodGroup: String, CaseIterable, Sendable {
    case ricePasta = "rice_pasta", bread, grain, meat, poultry, fish, egg, dairy, cheese
    case oilFat = "oil_fat", fruit, vegetables, nuts, drinks, other

    var title: String {
        switch self {
        case .ricePasta: "Ris, pasta og gryn"
        case .bread: "Brød og bakst"
        case .grain: "Korn og havre"
        case .meat: "Kjøtt"
        case .poultry: "Fjærkre"
        case .fish: "Fisk og sjømat"
        case .egg: "Egg"
        case .dairy: "Melk og yoghurt"
        case .cheese: "Ost"
        case .oilFat: "Olje og fett"
        case .fruit: "Frukt og bær"
        case .vegetables: "Grønnsaker"
        case .nuts: "Nøtter og frø"
        case .drinks: "Drikke"
        case .other: "Annen mat"
        }
    }

    var assetName: String { "food-" + rawValue }
}

/// Source-specific, deterministic mapping. Unrecognized or conflicting groups stay neutral.
nonisolated enum FoodGroupResolver {
    static func resolve(source: String, category: String?, tags: [String]? = nil,
                        selected: String? = nil) -> FoodGroup {
        if let selected, let group = FoodGroup(rawValue: selected) { return group }
        switch source {
        case "matvaretabellen": return norwegianCategory(category)
        case "openfoodfacts": return offCategory(tags: tags, category: category)
        default: return .other
        }
    }

    private static func norwegianCategory(_ category: String?) -> FoodGroup {
        guard let category else { return .other }
        return norwegianGroups.first { $0.1.contains(category) }?.0 ?? .other
    }

    private static let norwegianGroups: [(FoodGroup, [String])] = [
        (.dairy, ["1.1", "1.2", "1.3"]),
        (.cheese, ["1.4.4", "1.4.5", "1.4.6", "1.4.7", "1.4.8", "1.4.9"]),
        (.egg, ["2"]), (.poultry, ["3.1"]),
        (.meat, ["3.2", "3.3", "3.4", "3.5", "3.8", "3.9", "3.10"]),
        (.fish, ["4.1.1", "4.1.2", "4.1.5", "4.2", "4.3", "4.4"]),
        (.ricePasta, ["5.2"]), (.grain, ["5.1", "5.3", "5.12"]),
        (.bread, ["5.5.1", "5.5.2", "5.5.3", "5.6.1", "5.6.2", "5.6.3", "5.6.4", "5.6.5", "5.7", "5.8", "5.9", "5.10"]),
        (.vegetables, ["6.2", "6.6", "12", "15.1", "15.2"]),
        (.oilFat, ["8.1", "8.2", "8.5"]),
        (.drinks, ["9.1", "9.2", "9.3", "9.4", "9.5", "9.6"]),
        (.fruit, ["13.1", "13.2", "13.3"]), (.nuts, ["14.1", "14.2", "14.3"])
    ]

    // Exact aliases, never substrings of product names. Specific categories outrank parents.
    private static let aliases: [(FoodGroup, Int, [String])] = [
        (.ricePasta, 3, ["rice", "rices", "pasta", "pastas", "noodles", "ris", "basmati-rices"]),
        (.bread, 3, ["bread", "breads", "brod", "bakery-products", "pastries", "crispbreads"]),
        (.grain, 2, ["cereals", "cereal-flours", "oats", "oat-flakes", "havregryn", "flours"]),
        (.poultry, 3, ["poultry", "chickens", "chicken", "turkeys", "kylling"]),
        (.meat, 2, ["meats", "meat", "beef", "pork", "lamb", "kjott", "ground-meats"]),
        (.fish, 2, ["fish", "fishes", "seafood", "fisk", "salmon", "shellfish"]),
        (.egg, 2, ["eggs", "egg"]),
        (.cheese, 3, ["cheeses", "cheese", "ost"]),
        (.dairy, 2, ["dairies", "milks", "milk", "yogurts", "yoghurts", "melk", "yoghurt", "creams"]),
        (.oilFat, 2, ["fats", "vegetable-oils", "oils", "butters", "margarines", "oljer", "smor"]),
        (.fruit, 2, ["fruits", "berries", "fresh-fruits", "frukt", "baer"]),
        (.vegetables, 2, ["vegetables", "fresh-vegetables", "legumes", "potatoes", "gronnsaker"]),
        (.nuts, 2, ["nuts", "seeds", "notter", "fro"]),
        (.drinks, 3, ["waters", "juices", "fruit-juices", "sodas", "plant-milks"]),
        // Explicit dishes override ingredient/parent categories rather than pretending to be an ingredient.
        (.drinks, 1, ["beverages", "drikke"]),
        (.other, 4, ["meals", "prepared-meals", "pizzas", "soups", "sandwiches", "salads"])
    ]

    private static func offCategory(tags: [String]?, category: String?) -> FoodGroup {
        let values = (tags ?? []) + (category?.components(separatedBy: ",") ?? [])
        let normalized = Set(values.map { value in
            let value = value.split(separator: ":", maxSplits: 1).last.map(String.init) ?? value
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "nb_NO"))
                .replacingOccurrences(of: "ø", with: "o")
                .replacingOccurrences(of: "æ", with: "ae")
                .replacingOccurrences(of: " ", with: "-")
        })
        let matches = aliases.filter { entry in entry.2.contains { normalized.contains($0) } }
        guard let priority = matches.map({ $0.1 }).max() else { return .other }
        let groups = Set(matches.filter { $0.1 == priority }.map { $0.0 })
        return groups.count == 1 ? (groups.first ?? .other) : .other
    }
}

extension Product {
    var foodGroup: FoodGroup {
        FoodGroupResolver.resolve(source: source, category: category, tags: categoryTags, selected: selectedFoodGroup)
    }
}
