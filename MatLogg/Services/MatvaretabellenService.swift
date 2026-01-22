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
        let first = try await fetchProducts(query: query, queryParam: "query")
        if !first.isEmpty {
            return first
        }
        let fallback = try await fetchProducts(query: query, queryParam: "search")
        return fallback
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
            let name = dict["name"] as? String ?? dict["matvarenavn"] as? String
            guard let name, !name.isEmpty else { return nil }
            
            let id = dict["id"] as? String ?? UUID().uuidString
            let brand = dict["brand"] as? String ?? dict["merke"] as? String
            let category = dict["category"] as? String ?? dict["matvaregruppe"] as? String
            
            let nutrients = dict["nutrients"] as? [String: Any]
            let calories = (nutrients?["energy_kcal_100g"] as? NSNumber)?.intValue
                ?? (nutrients?["energi_kcal"] as? NSNumber)?.intValue
                ?? (dict["energy_kcal_100g"] as? NSNumber)?.intValue
                ?? (dict["energi_kcal"] as? NSNumber)?.intValue
                ?? 0
            let protein = (nutrients?["protein_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["protein"] as? NSNumber)?.floatValue
                ?? (dict["protein_100g"] as? NSNumber)?.floatValue
                ?? (dict["protein"] as? NSNumber)?.floatValue
                ?? 0
            let carbs = (nutrients?["carbs_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["karbohydrat"] as? NSNumber)?.floatValue
                ?? (dict["carbs_100g"] as? NSNumber)?.floatValue
                ?? (dict["karbohydrat"] as? NSNumber)?.floatValue
                ?? 0
            let fat = (nutrients?["fat_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["fett"] as? NSNumber)?.floatValue
                ?? (dict["fat_100g"] as? NSNumber)?.floatValue
                ?? (dict["fett"] as? NSNumber)?.floatValue
                ?? 0
            
            let sugar = (nutrients?["sugar_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["sukkerarter"] as? NSNumber)?.floatValue
            let fiber = (nutrients?["fiber_100g"] as? NSNumber)?.floatValue
                ?? (nutrients?["kostfiber"] as? NSNumber)?.floatValue
            let sodiumMg = (nutrients?["sodium_mg_100g"] as? NSNumber)?.intValue
                ?? (nutrients?["natrium"] as? NSNumber)?.intValue
            
            return MatvaretabellenProduct(
                id: id,
                name: name,
                brand: brand,
                category: category,
                caloriesPer100g: calories,
                proteinGPer100g: protein,
                carbsGPer100g: carbs,
                fatGPer100g: fat,
                sugarGPer100g: sugar,
                fiberGPer100g: fiber,
                sodiumMgPer100g: sodiumMg
            )
        }
        
        if let array = json as? [[String: Any]] {
            return array.compactMap(mapDict)
        }
        
        if let dict = json as? [String: Any] {
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
