import Foundation

class APIService {
    private let baseURL: String
    private let session: URLSession
    private let accessTokenProvider: () -> String?
    private let syncEnabled: () -> Bool

    init(
        session: URLSession = .shared,
        baseURL: String = "https://api.matlogg.app/v1",
        accessTokenProvider: @escaping () -> String? = { nil },
        syncEnabled: @escaping () -> Bool = { FeatureFlags.backendSyncEnabled }
    ) {
        self.session = session
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
        self.syncEnabled = syncEnabled
    }
    
    enum APIError: LocalizedError {
        case invalidURL
        case networkError(String)
        case decodingError
        case serverError(Int)
        case backendError(statusCode: Int, code: String?, message: String)
        case backendNotConfigured
        case batchLimitExceeded(Int)
        case payloadTooLarge(Int)
        case missingAccessToken
        case rateLimited(retryAfterSeconds: Int?)
        case incompleteProductData
        
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
            case .backendError(_, _, let message):
                return message
            case .backendNotConfigured:
                return "Backend ikke konfigurert"
            case .batchLimitExceeded(let limit):
                return "For mange sync-events i batch (maks \(limit))"
            case .payloadTooLarge(let limit):
                return "For stor payload i sync-event (maks \(limit) bytes)"
            case .missingAccessToken:
                return "Du må være innlogget for å synkronisere"
            case .rateLimited(let seconds):
                if let seconds {
                    return "Produktdatabasen ber oss vente. Prøv igjen om ca. \(seconds) sekunder."
                }
                return "Produktdatabasen ber oss vente litt før neste søk."
            case .incompleteProductData:
                return "Produktet mangler komplette næringsverdier per 100 g eller 100 ml."
            }
        }
    }

    struct UploadResult {
        let ackedEventIds: [UUID]
        let rejected: [RejectedEvent]
    }
    
    struct RejectedEvent {
        let eventId: UUID
        let code: String
        let message: String
    }
    
    struct SyncEventEnvelope: Codable {
        let eventId: UUID
        let type: String
        let createdAt: Date
        let entityId: String?
        let schemaVersion: Int
        let payload: String
    }
    
    struct UploadEventsRequest: Codable {
        let deviceId: UUID
        let clientTime: Date
        let events: [SyncEventEnvelope]
    }
    
    struct UploadEventsResponse: Codable {
        let ackedEventIds: [UUID]
        let rejected: [RejectedEventResponse]?
    }
    
    struct RejectedEventResponse: Codable {
        let eventId: UUID
        let code: String
        let message: String
    }
    
    // MARK: - Auth Endpoints

    private func endpointURL(_ path: String) throws -> URL {
        guard let url = URL(string: "\(baseURL)\(path)"),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            throw APIError.invalidURL
        }
        return url
    }
    
    func signupEmail(email: String, password: String, firstName: String, lastName: String) async throws -> (User, String) {
        let url = try endpointURL("/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password,
            "first_name": firstName,
            "last_name": lastName
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        try requireBackendSuccess(data: data, response: response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: authResponse.auth_provider,
            createdAt: authResponse.created_at
        )
        
        return (user, authResponse.token)
    }
    
    func loginEmail(email: String, password: String) async throws -> (User, String) {
        let url = try endpointURL("/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        try requireBackendSuccess(data: data, response: response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: authResponse.auth_provider,
            createdAt: authResponse.created_at
        )
        
        return (user, authResponse.token)
    }

    func deleteAccount() async throws -> AccountDeletionReceipt {
        guard let token = accessTokenProvider(), !token.isEmpty else {
            throw APIError.missingAccessToken
        }
        guard let url = URL(string: "\(baseURL)/user") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try requireBackendSuccess(data: data, response: response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AccountDeletionReceipt.self, from: data)
    }
    
    // MARK: - Sync (stub)
    
    func uploadEvents(_ events: [SyncEvent]) async throws -> UploadResult {
        guard syncEnabled() else {
            throw APIError.backendNotConfigured
        }
        
        let maxBatchSize = 50
        let maxPayloadBytes = 64 * 1024
        if events.count > maxBatchSize {
            throw APIError.batchLimitExceeded(maxBatchSize)
        }
        if events.contains(where: { $0.payload.count > maxPayloadBytes }) {
            throw APIError.payloadTooLarge(maxPayloadBytes)
        }
        guard let token = accessTokenProvider(), !token.isEmpty else {
            throw APIError.missingAccessToken
        }
        
        let url = try endpointURL("/sync/events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let envelopes = events.map { event in
            SyncEventEnvelope(
                eventId: event.eventId,
                type: event.type,
                createdAt: event.createdAt,
                entityId: event.entityId,
                schemaVersion: event.schemaVersion,
                payload: event.payload.base64EncodedString()
            )
        }
        
        let payload = UploadEventsRequest(
            deviceId: SyncDeviceIdentity.id,
            clientTime: Date(),
            events: envelopes
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(payload)
        
        let (data, response) = try await session.data(for: request)
        try requireBackendSuccess(data: data, response: response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UploadEventsResponse.self, from: data)
        let rejected = decoded.rejected?.map {
            RejectedEvent(eventId: $0.eventId, code: $0.code, message: $0.message)
        } ?? []
        
        #if DEBUG
        if !rejected.isEmpty {
            let rejectedSet = Set(rejected.map { $0.eventId })
            for event in events where rejectedSet.contains(event.eventId) {
                if let json = try? JSONSerialization.jsonObject(with: event.payload),
                   let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let text = String(data: pretty, encoding: .utf8) {
                    print("Sync rejected \(event.eventId):\n\(text)")
                } else if let text = String(data: event.payload, encoding: .utf8) {
                    print("Sync rejected \(event.eventId):\n\(text)")
                } else {
                    print("Sync rejected \(event.eventId): payload \(event.payload.count) bytes")
                }
            }
        }
        #endif
        
        return UploadResult(ackedEventIds: decoded.ackedEventIds, rejected: rejected)
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

    func searchProductsByNameOpenFoodFacts(_ query: String) async throws -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(string: "https://no.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(
                name: "fields",
                value: "code,product_name,brands,categories,image_front_url,serving_size,serving_quantity,product_quantity,product_quantity_unit,nutrition_data_per,nutriments,last_modified_t,rev,schema_version,data_quality_errors_tags,data_quality_warnings_tags"
            )
        ]
        guard let url = components?.url else { throw APIError.invalidURL }

        let data = try await openFoodFactsData(from: url)
        let response = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)

        return response.products.compactMap { product in
            makeOpenFoodFactsProduct(product, barcode: product.code, requiresCompleteMacros: true)
        }
    }
    
    func searchProductByBarcodeOpenFoodFacts(_ ean: String) async throws -> Product {
        let fields = [
            "code", "product_name", "brands", "categories", "image_front_url",
            "serving_size", "serving_quantity", "product_quantity", "product_quantity_unit",
            "nutrition_data_per", "nutriments", "last_modified_t", "rev", "schema_version",
            "data_quality_errors_tags", "data_quality_warnings_tags"
        ].joined(separator: ",")
        var components = URLComponents(string: "https://world.openfoodfacts.org/api/v3/product/\(ean)")
        components?.queryItems = [
            URLQueryItem(name: "cc", value: "no"),
            URLQueryItem(name: "lc", value: "nb"),
            URLQueryItem(name: "fields", value: fields)
        ]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }
        let data = try await openFoodFactsData(from: url)
        let responseData = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        
        guard responseData.status == "success", let product = responseData.product else {
            throw APIError.serverError(404)
        }

        guard let mapped = makeOpenFoodFactsProduct(
            product,
            barcode: product.code ?? ean,
            requiresCompleteMacros: true
        ) else {
            throw APIError.incompleteProductData
        }
        return mapped
    }

    private func openFoodFactsData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.setValue(openFoodFactsUserAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.rateLimited(retryAfterSeconds: retryAfter)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        return data
    }

    private var openFoodFactsUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        return "MatLogg/\(version) (mailto:nithusank.2002@gmail.com)"
    }

    private func requireBackendSuccess(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let decoded = try? JSONDecoder().decode(BackendErrorResponse.self, from: data)
            throw APIError.backendError(
                statusCode: httpResponse.statusCode,
                code: decoded?.code,
                message: decoded?.message ?? "Serverfeil (\(httpResponse.statusCode))"
            )
        }
    }

    private func makeOpenFoodFactsProduct(
        _ product: OpenFoodFactsProduct,
        barcode: String?,
        requiresCompleteMacros: Bool
    ) -> Product? {
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }

        let nutriments = product.nutriments
        let completeNutrition = validatedNutrition(nutriments)
        if requiresCompleteMacros, completeNutrition == nil {
            return nil
        }
        guard let completeNutrition else { return nil }

        let servings = buildServingOptions(
            name: name,
            servingSize: product.servingSize,
            servingQuantity: product.servingQuantity?.value,
            productQuantity: product.productQuantity?.value,
            productQuantityUnit: product.productQuantityUnit
        )
        let nutritionBasis = nutritionBasis(
            nutritionDataPer: product.nutritionDataPer,
            productQuantityUnit: product.productQuantityUnit
        )

        return Product(
            id: barcode.map { Product.catalogID(source: "openfoodfacts", externalID: $0) } ?? UUID(),
            name: name,
            brand: product.brands,
            category: product.categories,
            barcodeEan: barcode,
            source: "openfoodfacts",
            kind: .packaged,
            caloriesPer100g: Int(completeNutrition.energyKcal.rounded()),
            proteinGPer100g: Float(completeNutrition.protein),
            carbsGPer100g: Float(completeNutrition.carbohydrates),
            fatGPer100g: Float(completeNutrition.fat),
            sugarGPer100g: nutriments?.sugars100g.map(Float.init),
            fiberGPer100g: nutriments?.fiber100g.map(Float.init),
            sodiumMgPer100g: nutriments?.sodium100g.map { Int(($0 * 1000).rounded()) },
            imageUrl: product.imageUrl,
            servings: servings,
            nutritionSource: .openFoodFacts,
            imageSource: product.imageUrl == nil ? .none : .openFoodFacts,
            verificationStatus: .unverified,
            isVerified: false,
            createdAt: Date(),
            externalID: barcode,
            nutritionBasis: nutritionBasis,
            sourceUpdatedAt: product.lastModifiedTimestamp.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            sourceRevision: product.revision,
            sourceSchemaVersion: product.schemaVersion,
            fetchedAt: Date(),
            dataQualityWarnings: (product.dataQualityErrors ?? []) + (product.dataQualityWarnings ?? [])
        )
    }

    private func validatedNutrition(_ nutriments: OpenFoodFactsNutriments?) -> CompleteNutrition? {
        guard let energyKcal = nutriments?.energyKcal100g,
              let protein = nutriments?.protein100g,
              let carbohydrates = nutriments?.carbs100g,
              let fat = nutriments?.fat100g,
              energyKcal.isFinite, (0...1_000).contains(energyKcal),
              protein.isFinite, (0...100).contains(protein),
              carbohydrates.isFinite, (0...100).contains(carbohydrates),
              fat.isFinite, (0...100).contains(fat) else {
            return nil
        }
        return CompleteNutrition(
            energyKcal: energyKcal,
            protein: protein,
            carbohydrates: carbohydrates,
            fat: fat
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
        
        if let servingSize, let parsed = parseAmount(from: servingSize) {
            let label = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
            options.append(
                ServingOption(
                    label: label,
                    grams: parsed.value,
                    unit: parsed.unit,
                    source: .openFoodFacts,
                    isDefaultSuggestion: true
                )
            )
            
            if label.lowercased().contains("bar"), parsed.unit == .grams {
                let half = parsed.value / 2.0
                let halfLabel = "1/2 bar (\(formatGrams(half)) g)"
                options.append(
                    ServingOption(
                        label: halfLabel,
                        grams: half,
                        source: .heuristic
                    )
                )
            }
        } else if let servingQuantity, servingQuantity > 0,
                  let unit = amountUnit(from: productQuantityUnit) {
            let label = "1 porsjon (\(formatGrams(servingQuantity)) \(unit.rawValue))"
            options.append(
                ServingOption(
                    label: label,
                    grams: servingQuantity,
                    unit: unit,
                    source: .openFoodFacts,
                    isDefaultSuggestion: true
                )
            )
        }
        
        if options.isEmpty {
            if let quantity = parseQuantity(productQuantity: productQuantity, unit: productQuantityUnit) {
                let isBar = name.lowercased().contains("bar")
                let label = isBar && quantity.unit == .grams
                    ? "1 bar (\(formatGrams(quantity.value)) g)"
                    : "1 porsjon (\(formatGrams(quantity.value)) \(quantity.unit.rawValue))"
                options.append(
                    ServingOption(
                        label: label,
                        grams: quantity.value,
                        unit: quantity.unit,
                        source: .heuristic,
                        isDefaultSuggestion: true
                    )
                )
                
                if isBar, quantity.unit == .grams {
                    let half = quantity.value / 2.0
                    let halfLabel = "1/2 bar (\(formatGrams(half)) g)"
                    options.append(
                        ServingOption(
                            label: halfLabel,
                            grams: half,
                            source: .heuristic
                        )
                    )
                }
            } else if let parsed = parseAmount(from: name), parsed.unit == .grams {
                let isBar = name.lowercased().contains("bar")
                let label = isBar ? "1 bar (\(formatGrams(parsed.value)) g)" : "1 porsjon (\(formatGrams(parsed.value)) g)"
                options.append(
                    ServingOption(
                        label: label,
                        grams: parsed.value,
                        unit: .grams,
                        source: .heuristic,
                        isDefaultSuggestion: true
                    )
                )
            }
        }
        
        if options.isEmpty {
            return nil
        }
        
        let defaultUnit = amountUnit(from: productQuantityUnit) ?? options.first?.amountUnit ?? .grams
        let has100 = options.contains { abs($0.grams - 100.0) < 0.1 && $0.amountUnit == defaultUnit }
        if !has100 {
            options.append(
                ServingOption(
                    label: "100 \(defaultUnit.rawValue)",
                    grams: 100.0,
                    unit: defaultUnit,
                    source: .heuristic
                )
            )
        }
        
        return options
    }
    
    private func parseAmount(from text: String) -> (value: Double, unit: AmountUnit)? {
        let pattern = #"([0-9]+(?:[.,][0-9]+)?)\s*(ml|g)\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let numberRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let value = text[numberRange].replacingOccurrences(of: ",", with: ".")
        guard let number = Double(value), let unit = amountUnit(from: String(text[unitRange])) else { return nil }
        return (number, unit)
    }
    
    private func parseQuantity(productQuantity: Double?, unit: String?) -> (value: Double, unit: AmountUnit)? {
        guard let productQuantity, productQuantity > 0,
              let amountUnit = amountUnit(from: unit) else { return nil }
        return (productQuantity, amountUnit)
    }

    private func amountUnit(from rawValue: String?) -> AmountUnit? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams": return .grams
        case "ml", "milliliter", "milliliters", "millilitres": return .milliliters
        default: return nil
        }
    }

    private func nutritionBasis(nutritionDataPer: String?, productQuantityUnit: String?) -> NutritionBasis {
        let normalized = nutritionDataPer?.lowercased().replacingOccurrences(of: " ", with: "")
        if normalized == "100ml" { return .per100ml }
        if normalized == nil, amountUnit(from: productQuantityUnit) == .milliliters { return .per100ml }
        return .per100g
    }
    
    private func formatGrams(_ grams: Double) -> String {
        if grams.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(grams))
        }
        return String(format: "%.1f", grams)
    }
}

private struct AuthResponse: Decodable {
    let user_id: UUID
    let email: String
    let first_name: String
    let last_name: String
    let auth_provider: String
    let created_at: Date
    let token: String
}

private struct BackendErrorResponse: Decodable {
    let code: String?
    let message: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case error
        case message
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
            ?? container.decodeIfPresent(String.self, forKey: .error)
        if let text = try? container.decode(String.self, forKey: .message) {
            message = text
        } else if let messages = try? container.decode([String].self, forKey: .message) {
            message = messages.joined(separator: " ")
        } else {
            message = nil
        }
    }
}

private struct OpenFoodFactsResponse: Codable {
    let status: String
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsSearchResponse: Codable {
    let products: [OpenFoodFactsProduct]
}

private struct OpenFoodFactsProduct: Codable {
    let code: String?
    let productName: String?
    let brands: String?
    let categories: String?
    let imageUrl: String?
    let servingSize: String?
    let servingQuantity: FlexibleDouble?
    let productQuantity: FlexibleDouble?
    let productQuantityUnit: String?
    let nutriments: OpenFoodFactsNutriments?
    let nutritionDataPer: String?
    let lastModifiedTimestamp: Int?
    let revision: Int?
    let schemaVersion: Int?
    let dataQualityErrors: [String]?
    let dataQualityWarnings: [String]?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case categories
        case imageUrl = "image_front_url"
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case productQuantity = "product_quantity"
        case productQuantityUnit = "product_quantity_unit"
        case nutriments
        case nutritionDataPer = "nutrition_data_per"
        case lastModifiedTimestamp = "last_modified_t"
        case revision = "rev"
        case schemaVersion = "schema_version"
        case dataQualityErrors = "data_quality_errors_tags"
        case dataQualityWarnings = "data_quality_warnings_tags"
    }
}

private struct CompleteNutrition {
    let energyKcal: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
}

private struct OpenFoodFactsNutriments: Codable {
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

private enum SyncDeviceIdentity {
    private static let key = "ml_sync_device_id"

    static var id: UUID {
        if let value = UserDefaults.standard.string(forKey: key),
           let existing = UUID(uuidString: value) {
            return existing
        }
        let created = UUID()
        UserDefaults.standard.set(created.uuidString, forKey: key)
        return created
    }
}

private struct FlexibleDouble: Codable {
    let value: Double?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let intValue = try? container.decode(Int.self) {
            value = Double(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            let normalized = stringValue.replacingOccurrences(of: ",", with: ".")
            value = Double(normalized)
        } else {
            value = nil
        }
    }
}
