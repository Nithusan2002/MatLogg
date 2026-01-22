import Foundation

struct MatvaretabellenProduct {
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

final class MatvaretabellenService {
    private let baseURL = URL(string: "https://www.matvaretabellen.no")!
    private let session = URLSession.shared
    
    func searchProducts(query: String) async throws -> [MatvaretabellenProduct] {
        let params = ["query", "search", "q", "name"]
        var results: [MatvaretabellenProduct] = []
        var seen = Set<String>()
        
        for param in params {
            let items = try await fetchProducts(query: query, queryParam: param)
            for item in items {
                let key = item.name.lowercased()
                if seen.insert(key).inserted {
                    results.append(item)
                }
            }
            if !results.isEmpty {
                break
            }
        }
        
        return results
    }
    
    func fetchCommonFoods() async throws -> [MatvaretabellenProduct] {
        let seeds = [
            "banan", "eple", "appelsin", "potet", "gulrot",
            "tomat", "agurk", "brokkoli", "salat", "paprika",
            "kylling", "laks", "torsk", "egg", "ris",
            "pasta", "havregryn", "yoghurt", "melk", "brød"
        ]
        
        var results: [MatvaretabellenProduct] = []
        var seen = Set<String>()
        for seed in seeds {
            let items = try await searchProducts(query: seed)
            for item in items {
                if seen.insert(item.name.lowercased()).inserted {
                    results.append(item)
                }
            }
            if results.count >= 50 {
                break
            }
        }
        return results
    }
    
    private func fetchProducts(query: String, queryParam: String) async throws -> [MatvaretabellenProduct] {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/nb/foods.json"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: queryParam, value: query)
        ]
        
        guard let url = components?.url else {
            return []
        }
        
        let (data, _) = try await session.data(from: url)
        return MatvaretabellenResponseParser.parse(data: data)
    }
}

enum MatvaretabellenResponseParser {
    static func parse(data: Data) -> [MatvaretabellenProduct] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        
        func mapDict(_ dict: [String: Any]) -> MatvaretabellenProduct? {
            let name = dict["foodName"] as? String ?? dict["name"] as? String ?? dict["matvarenavn"] as? String
            guard let name, !name.isEmpty else { return nil }
            
            let id = dict["id"] as? String ?? dict["foodId"] as? String ?? UUID().uuidString
            let brand = dict["brand"] as? String ?? dict["merke"] as? String
            let category = dict["category"] as? String ?? dict["matvaregruppe"] as? String
            
            let calories = extractCalories(dict)
            let protein = extractNutrient(dict, keys: ["protein_100g", "protein"], nutrientIds: ["Protein"])
            let carbs = extractNutrient(dict, keys: ["carbs_100g", "karbohydrat"], nutrientIds: ["Karbohydrat"])
            let fat = extractNutrient(dict, keys: ["fat_100g", "fett"], nutrientIds: ["Fett"])
            let sugar = extractNutrient(dict, keys: ["sugar_100g", "sukkerarter"], nutrientIds: ["Mono+Di"])
            let fiber = extractNutrient(dict, keys: ["fiber_100g", "kostfiber"], nutrientIds: ["Kostfiber"])
            let sodiumMg = Int(extractNutrient(dict, keys: ["sodium_mg_100g", "natrium"], nutrientIds: ["Na"]).rounded())
            
            let nutrients = dict["nutrients"] as? [String: Any]
            let caloriesFromNutrients = (nutrients?["energy_kcal_100g"] as? NSNumber)?.intValue
                ?? (nutrients?["energi_kcal"] as? NSNumber)?.intValue
                ?? (dict["energy_kcal_100g"] as? NSNumber)?.intValue
                ?? (dict["energi_kcal"] as? NSNumber)?.intValue
            let proteinFromNutrients = (nutrients?["protein_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["protein"] as? NSNumber)?.floatValue
                ?? (dict["protein_100g"] as? NSNumber)?.floatValue
                ?? (dict["protein"] as? NSNumber)?.floatValue
            let carbsFromNutrients = (nutrients?["carbs_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["karbohydrat"] as? NSNumber)?.floatValue
                ?? (dict["carbs_100g"] as? NSNumber)?.floatValue
                ?? (dict["karbohydrat"] as? NSNumber)?.floatValue
            let fatFromNutrients = (nutrients?["fat_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["fett"] as? NSNumber)?.floatValue
                ?? (dict["fat_100g"] as? NSNumber)?.floatValue
                ?? (dict["fett"] as? NSNumber)?.floatValue
            let sugarFromNutrients = (nutrients?["sugar_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["sukkerarter"] as? NSNumber)?.floatValue
            let fiberFromNutrients = (nutrients?["fiber_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["kostfiber"] as? NSNumber)?.floatValue
            let sodiumFromNutrients = (nutrients?["sodium_mg_100g"] as? NSNumber)?.intValue
                ?? (nutrients?["natrium"] as? NSNumber)?.intValue
            
            return MatvaretabellenProduct(
                id: id,
                name: name,
                brand: brand,
                category: category,
                caloriesPer100g: caloriesFromNutrients ?? calories,
                proteinGPer100g: proteinFromNutrients ?? protein,
                carbsGPer100g: carbsFromNutrients ?? carbs,
                fatGPer100g: fatFromNutrients ?? fat,
                sugarGPer100g: sugarFromNutrients ?? sugar,
                fiberGPer100g: fiberFromNutrients ?? fiber,
                sodiumMgPer100g: sodiumFromNutrients ?? sodiumMg
            )
        }
        
        if let array = json as? [[String: Any]] {
            return array.compactMap(mapDict)
        }
        
        if let dict = json as? [String: Any] {
            if let foods = dict["foods"] as? [[String: Any]] {
                return foods.compactMap(mapDict)
            }
            if let results = dict["results"] as? [[String: Any]] {
                return results.compactMap(mapDict)
            }
            if let items = dict["items"] as? [[String: Any]] {
                return items.compactMap(mapDict)
            }
        }
        
        return []
    }
}

private func extractCalories(_ dict: [String: Any]) -> Int {
    if let calories = dict["calories"] as? [String: Any],
       let quantity = calories["quantity"] as? NSNumber {
        return quantity.intValue
    }
    if let calories = dict["calories"] as? NSNumber {
        return calories.intValue
    }
    return 0
}

private func extractNutrient(_ dict: [String: Any], keys: [String], nutrientIds: [String]) -> Float {
    for key in keys {
        if let value = dict[key] as? NSNumber {
            return value.floatValue
        }
    }
    if let nutrients = dict["nutrients"] as? [String: Any] {
        for key in keys {
            if let value = nutrients[key] as? NSNumber {
                return value.floatValue
            }
        }
    }
    if let constituents = dict["constituents"] as? [[String: Any]] {
        for item in constituents {
            if let nutrientId = item["nutrientId"] as? String,
               nutrientIds.contains(nutrientId),
               let quantity = item["quantity"] as? NSNumber {
                return quantity.floatValue
            }
        }
    }
    return 0
}
