import Foundation

class APIService {
    private let baseURL = "https://api.matlogg.app/v1"
    private let session = URLSession.shared
    
    enum APIError: LocalizedError {
        case invalidURL
        case networkError(String)
        case decodingError
        case serverError(Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Ugyldig URL"
            case .networkError(let message):
                return message
            case .decodingError:
                return "Kunne ikke tolke svar fra server"
            case .serverError(let code):
                return "Server feil: \(code)"
            }
        }
    }
    
    // MARK: - Auth Endpoints
    
    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, String) {
        let url = URL(string: "\(baseURL)/auth/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "first_name": firstName,
            "last_name": lastName,
            "auth_provider": "email"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct AuthResponse: Codable {
            let user_id: UUID
            let email: String
            let first_name: String
            let last_name: String
            let token: String
        }
        
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: "email",
            createdAt: Date()
        )
        
        return (user, authResponse.token)
    }
    
    func loginEmail(email: String, password: String) async throws -> (User, String) {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct AuthResponse: Codable {
            let user_id: UUID
            let email: String
            let first_name: String
            let last_name: String
            let token: String
        }
        
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: "email",
            createdAt: Date()
        )
        
        return (user, authResponse.token)
    }
    
    // MARK: - Product Barcode Lookup
    
    func searchProductByBarcode(_ ean: String) async throws -> Product {
        guard let url = URL(string: "\(baseURL)/products/barcode/\(ean)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        
        if httpResponse.statusCode == 404 {
            throw APIError.serverError(404)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        struct ProductResponse: Codable {
            let product_id: UUID
            let name: String
            let brand: String?
            let category: String?
            let barcode_ean: String?
            let calories_per_100g: Int
            let protein_g_per_100g: Float
            let carbs_g_per_100g: Float
            let fat_g_per_100g: Float
            let sugar_g_per_100g: Float?
            let fiber_g_per_100g: Float?
            let sodium_mg_per_100g: Int?
            let image_url: String?
            let is_verified: Bool
            let created_at: Date
        }
        
        let productResponse = try decoder.decode(ProductResponse.self, from: data)
        
        return Product(
            id: productResponse.product_id,
            name: productResponse.name,
            brand: productResponse.brand,
            category: productResponse.category,
            barcodeEan: productResponse.barcode_ean,
            source: "matvaretabellen",
            kind: .packaged,
            caloriesPer100g: productResponse.calories_per_100g,
            proteinGPer100g: productResponse.protein_g_per_100g,
            carbsGPer100g: productResponse.carbs_g_per_100g,
            fatGPer100g: productResponse.fat_g_per_100g,
            sugarGPer100g: productResponse.sugar_g_per_100g,
            fiberGPer100g: productResponse.fiber_g_per_100g,
            sodiumMgPer100g: productResponse.sodium_mg_per_100g,
            imageUrl: productResponse.image_url,
            nutritionSource: .matvaretabellen,
            imageSource: productResponse.image_url == nil ? .none : .openFoodFacts,
            verificationStatus: .verified,
            isVerified: productResponse.is_verified,
            createdAt: productResponse.created_at
        )
    }
    
    // MARK: - Open Food Facts Lookup
    
    func searchProductByBarcodeOpenFoodFacts(_ ean: String) async throws -> Product {
        guard let url = URL(string: "https://no.openfoodfacts.org/api/v0/product/\(ean).json") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("MatLogg iOS (com.nithusan.MatLogg)", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        struct OpenFoodFactsResponse: Codable {
            let status: Int
            let code: String?
            let product: OpenFoodFactsProduct?
        }
        
        struct OpenFoodFactsProduct: Codable {
            let productName: String?
            let brands: String?
            let categories: String?
            let imageUrl: String?
            let servingSize: String?
            let servingQuantity: FlexibleDouble?
            let productQuantity: FlexibleDouble?
            let productQuantityUnit: String?
            let nutriments: Nutriments?
            
            struct Nutriments: Codable {
                let energyKcal100g: Double?
                let protein100g: Double?
                let carbs100g: Double?
                let fat100g: Double?
                let sugars100g: Double?
                let fiber100g: Double?
                let sodium100g: Double?
                
                enum CodingKeys: String, CodingKey {
                    case energyKcal100g = "energy-kcal_100g"
                    case protein100g = "proteins_100g"
                    case carbs100g = "carbohydrates_100g"
                    case fat100g = "fat_100g"
                    case sugars100g = "sugars_100g"
                    case fiber100g = "fiber_100g"
                    case sodium100g = "sodium_100g"
                }
            }
            
            enum CodingKeys: String, CodingKey {
                case productName = "product_name"
                case brands
                case categories
                case imageUrl = "image_url"
                case servingSize = "serving_size"
                case servingQuantity = "serving_quantity"
                case productQuantity = "product_quantity"
                case productQuantityUnit = "product_quantity_unit"
                case nutriments
            }
        }
        
        let decoder = JSONDecoder()
        let responseData = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        
        guard responseData.status == 1, let product = responseData.product else {
            throw APIError.serverError(404)
        }
        
        let nutriments = product.nutriments
        let calories = Int((nutriments?.energyKcal100g ?? 0).rounded())
        let protein = Float(nutriments?.protein100g ?? 0)
        let carbs = Float(nutriments?.carbs100g ?? 0)
        let fat = Float(nutriments?.fat100g ?? 0)
        let sugar = nutriments?.sugars100g.map { Float($0) }
        let fiber = nutriments?.fiber100g.map { Float($0) }
        let sodiumMg = nutriments?.sodium100g.map { Int(($0 * 1000).rounded()) }
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = (name?.isEmpty == false) ? name! : "Ukjent produkt"
        let servings = buildServingOptions(
            name: displayName,
            servingSize: product.servingSize,
            servingQuantity: product.servingQuantity?.value,
            productQuantity: product.productQuantity?.value,
            productQuantityUnit: product.productQuantityUnit
        )
        
        return Product(
            id: UUID(),
            name: displayName,
            brand: product.brands,
            category: product.categories,
            barcodeEan: responseData.code ?? ean,
            source: "openfoodfacts",
            kind: .packaged,
            caloriesPer100g: calories,
            proteinGPer100g: protein,
            carbsGPer100g: carbs,
            fatGPer100g: fat,
            sugarGPer100g: sugar,
            fiberGPer100g: fiber,
            sodiumMgPer100g: sodiumMg,
            imageUrl: product.imageUrl,
            servings: servings,
            nutritionSource: .openFoodFacts,
            imageSource: product.imageUrl == nil ? .none : .openFoodFacts,
            verificationStatus: .unverified,
            isVerified: false,
            createdAt: Date()
        )
    }
    
    private func buildServingOptions(
        name: String,
        servingSize: String?,
        servingQuantity: Double?,
        productQuantity: Double?,
        productQuantityUnit: String?
    ) -> [ServingOption]? {
        var options: [ServingOption] = []
        
        if let servingSize, let grams = parseGrams(from: servingSize) {
            let label = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
            options.append(
                ServingOption(
                    label: label,
                    grams: grams,
                    source: .openFoodFacts,
                    isDefaultSuggestion: true
                )
            )
            
            if label.lowercased().contains("bar") {
                let half = grams / 2.0
                let halfLabel = "1/2 bar (\(formatGrams(half)) g)"
                options.append(
                    ServingOption(
                        label: halfLabel,
                        grams: half,
                        source: .heuristic
                    )
                )
            }
        } else if let servingQuantity, servingQuantity > 0 {
            let label = "1 porsjon (\(formatGrams(servingQuantity)) g)"
            options.append(
                ServingOption(
                    label: label,
                    grams: servingQuantity,
                    source: .openFoodFacts,
                    isDefaultSuggestion: true
                )
            )
        }
        
        if options.isEmpty {
            if let grams = parseQuantity(productQuantity: productQuantity, unit: productQuantityUnit) {
                let isBar = name.lowercased().contains("bar")
                let label = isBar ? "1 bar (\(formatGrams(grams)) g)" : "1 porsjon (\(formatGrams(grams)) g)"
                options.append(
                    ServingOption(
                        label: label,
                        grams: grams,
                        source: .heuristic,
                        isDefaultSuggestion: true
                    )
                )
                
                if isBar {
                    let half = grams / 2.0
                    let halfLabel = "1/2 bar (\(formatGrams(half)) g)"
                    options.append(
                        ServingOption(
                            label: halfLabel,
                            grams: half,
                            source: .heuristic
                        )
                    )
                }
            } else if let grams = parseGrams(from: name) {
                let isBar = name.lowercased().contains("bar")
                let label = isBar ? "1 bar (\(formatGrams(grams)) g)" : "1 porsjon (\(formatGrams(grams)) g)"
                options.append(
                    ServingOption(
                        label: label,
                        grams: grams,
                        source: .heuristic,
                        isDefaultSuggestion: true
                    )
                )
            }
        }
        
        if options.isEmpty {
            return nil
        }
        
        let has100 = options.contains { abs($0.grams - 100.0) < 0.1 }
        if !has100 {
            options.append(
                ServingOption(
                    label: "100 g",
                    grams: 100.0,
                    source: .heuristic
                )
            )
        }
        
        return options
    }
    
    private func parseGrams(from text: String) -> Double? {
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*g"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = text[numberRange].replacingOccurrences(of: ",", with: ".")
        return Double(value)
    }
    
    private func parseQuantity(productQuantity: Double?, unit: String?) -> Double? {
        guard let productQuantity, productQuantity > 0 else { return nil }
        let unitValue = unit?.lowercased()
        if unitValue == "g" || unitValue == "gram" || unitValue == "grams" || unitValue == nil {
            return productQuantity
        }
        return nil
    }
    
    private func formatGrams(_ grams: Double) -> String {
        if grams.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(grams))
        }
        return String(format: "%.1f", grams)
    }
}

private struct FlexibleDouble: Codable {
    let value: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            value = Double(normalized) ?? 0
        } else {
            value = 0
        }
    }
}
