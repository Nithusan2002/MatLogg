import Foundation

nonisolated struct MatvaretabellenProduct: Codable, Sendable {
    let id: String
    let name: String
    let brand: String?
    let category: String?
    let caloriesPer100g: Int
    let proteinGPer100g: Float
    let carbsGPer100g: Float
    let fatGPer100g: Float
    let sugarGPer100g: Float?
    let fiberGPer100g: Float?
    let sodiumMgPer100g: Int?
}

/// Provides the official Norwegian food table as a bundled, searchable snapshot.
// Catalog state and file decoding are confined to queue.
nonisolated final class MatvaretabellenService: @unchecked Sendable {
    private let queue = DispatchQueue(label: "matlogg.bundled-catalog", qos: .userInitiated)
    private let bundledData: () throws -> Data
    private var loadedCatalog: [MatvaretabellenProduct]?

    init(
        bundle: Bundle = .main,
        bundledData: (() throws -> Data)? = nil
    ) {
        self.bundledData = bundledData ?? {
            guard let url = bundle.url(forResource: "matvaretabellen-nb", withExtension: "json") else {
                throw MatvaretabellenCatalogError.missingBundledCatalog
            }
            return try Data(contentsOf: url, options: .mappedIfSafe)
        }
    }

    func searchProducts(query: String) async throws -> [MatvaretabellenProduct] {
        let catalog = try await loadCatalog()
        return catalog.filter {
            catalogSearchMatches(query: query, name: $0.name, brand: $0.brand)
        }
    }

    func fetchCommonFoods() async throws -> [MatvaretabellenProduct] {
        try await loadCatalog()
    }

    nonisolated private func loadCatalog() async throws -> [MatvaretabellenProduct] {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result {
                    if let loadedCatalog = self.loadedCatalog { return loadedCatalog }
                    let data = try self.bundledData()
                    let products = MatvaretabellenResponseParser.parse(data: data)
                    guard !products.isEmpty else { throw MatvaretabellenCatalogError.invalidCatalog }
                    self.loadedCatalog = products
                    return products
                })
            }
        }
    }
}

nonisolated enum MatvaretabellenCatalogError: Error {
    case missingBundledCatalog
    case invalidCatalog
}

nonisolated enum MatvaretabellenResponseParser {
    static func parse(data: Data) -> [MatvaretabellenProduct] {
        if let normalized = try? JSONDecoder().decode([MatvaretabellenProduct].self, from: data) {
            return normalized
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }

        func mapDict(_ dict: [String: Any]) -> MatvaretabellenProduct? {
            let name = dict["foodName"] as? String ?? dict["name"] as? String ?? dict["matvarenavn"] as? String
            guard let name, !name.isEmpty else { return nil }

            let id = dict["id"] as? String ?? dict["foodId"] as? String ?? UUID().uuidString
            let brand = dict["brand"] as? String ?? dict["merke"] as? String
            let category = dict["category"] as? String ?? dict["foodGroupId"] as? String ?? dict["matvaregruppe"] as? String
            let nutrients = dict["nutrients"] as? [String: Any]

            let calories = number(in: nutrients, keys: ["energy_kcal_100g", "energi_kcal"])
                ?? number(in: dict, keys: ["energy_kcal_100g", "energi_kcal"])
                ?? extractCalories(dict)
            let protein = number(in: nutrients, keys: ["protein_100g", "protein"])
                ?? number(in: dict, keys: ["protein_100g", "protein"])
                ?? extractNutrient(dict, keys: ["protein_100g", "protein"], nutrientIds: ["Protein"])
            let carbs = number(in: nutrients, keys: ["carbs_100g", "karbohydrat"])
                ?? number(in: dict, keys: ["carbs_100g", "karbohydrat"])
                ?? extractNutrient(dict, keys: ["carbs_100g", "karbohydrat"], nutrientIds: ["Karbo", "Karbohydrat"])
            let fat = number(in: nutrients, keys: ["fat_100g", "fett"])
                ?? number(in: dict, keys: ["fat_100g", "fett"])
                ?? extractNutrient(dict, keys: ["fat_100g", "fett"], nutrientIds: ["Fett"])

            // Required macro values must be present. Missing source data is never converted to zero.
            guard let calories, let protein, let carbs, let fat else { return nil }

            let sugar = number(in: nutrients, keys: ["sugar_100g", "sukkerarter"])
                ?? extractNutrient(dict, keys: ["sugar_100g", "sukkerarter"], nutrientIds: ["Mono+Di"])
            let fiber = number(in: nutrients, keys: ["fiber_100g", "kostfiber"])
                ?? extractNutrient(dict, keys: ["fiber_100g", "kostfiber"], nutrientIds: ["Fiber", "Kostfiber"])
            let sodium = number(in: nutrients, keys: ["sodium_mg_100g", "natrium"])
                ?? extractNutrient(dict, keys: ["sodium_mg_100g", "natrium"], nutrientIds: ["Na"])

            return MatvaretabellenProduct(
                id: id,
                name: name,
                brand: brand,
                category: category,
                caloriesPer100g: Int(calories.rounded()),
                proteinGPer100g: protein,
                carbsGPer100g: carbs,
                fatGPer100g: fat,
                sugarGPer100g: sugar,
                fiberGPer100g: fiber,
                sodiumMgPer100g: sodium.map { Int($0.rounded()) }
            )
        }

        if let array = json as? [[String: Any]] { return array.compactMap(mapDict) }
        if let dict = json as? [String: Any] {
            for key in ["foods", "results", "items"] {
                if let values = dict[key] as? [[String: Any]] { return values.compactMap(mapDict) }
            }
        }
        return []
    }
}

nonisolated private func number(in dict: [String: Any]?, keys: [String]) -> Float? {
    guard let dict else { return nil }
    for key in keys {
        if let value = dict[key] as? NSNumber { return value.floatValue }
    }
    return nil
}

nonisolated private func extractCalories(_ dict: [String: Any]) -> Float? {
    if let calories = dict["calories"] as? [String: Any],
       let quantity = calories["quantity"] as? NSNumber {
        return quantity.floatValue
    }
    return (dict["calories"] as? NSNumber)?.floatValue
}

nonisolated private func extractNutrient(_ dict: [String: Any], keys: [String], nutrientIds: [String]) -> Float? {
    if let value = number(in: dict, keys: keys) { return value }
    if let value = number(in: dict["nutrients"] as? [String: Any], keys: keys) { return value }
    guard let constituents = dict["constituents"] as? [[String: Any]] else { return nil }
    return constituents.first { item in
        guard let nutrientId = item["nutrientId"] as? String else { return false }
        return nutrientIds.contains(nutrientId) && item["quantity"] is NSNumber
    }.flatMap { ($0["quantity"] as? NSNumber)?.floatValue }
}

nonisolated private func catalogSearchMatches(query: String, name: String, brand: String?) -> Bool {
    func normalized(_ value: String) -> String {
        let folded = value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let tokens = normalized(query).split(separator: " ")
    guard !tokens.isEmpty else { return false }
    let searchableText = normalized([name, brand].compactMap { $0 }.joined(separator: " "))
    return tokens.allSatisfy { searchableText.contains($0) }
}
