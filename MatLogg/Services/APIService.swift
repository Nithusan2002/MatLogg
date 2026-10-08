import Foundation

class APIService {
    private static let productionBaseURL = "https://api.matlogg.app/v1"

    private static var defaultBaseURL: String {
#if DEBUG
        ProcessInfo.processInfo.environment["MATLOGG_API_BASE_URL"] ?? productionBaseURL
#else
        productionBaseURL
#endif
    }

    private let baseURL: String
    private let httpClient: any HTTPClientProtocol
    private let accessTokenProvider: () -> String?
    private let authSessionStore: (any AuthSessionStore)?
    private let refreshCoordinator: TokenRefreshCoordinator
    private let syncEnabled: () -> Bool
    private let catalogRetryLimit: Int
    private let sleep: (TimeInterval) async throws -> Void

    init(
        httpClient: any HTTPClientProtocol = URLSessionHTTPClient(),
        baseURL: String? = nil,
        accessTokenProvider: @escaping () -> String? = { nil },
        authSessionStore: (any AuthSessionStore)? = nil,
        refreshCoordinator: TokenRefreshCoordinator = TokenRefreshCoordinator(),
        syncEnabled: @escaping () -> Bool = { FeatureFlags.backendSyncEnabled },
        catalogRetryLimit: Int = 1,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL ?? Self.defaultBaseURL
        self.accessTokenProvider = accessTokenProvider
        self.authSessionStore = authSessionStore
        self.refreshCoordinator = refreshCoordinator
        self.syncEnabled = syncEnabled
        self.catalogRetryLimit = max(0, catalogRetryLimit)
        self.sleep = sleep
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
        case sessionExpired
        case credentialPersistenceFailed
        case rateLimited(retryAfterSeconds: Int?)
        case incompleteProductData
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Ugyldig URL"
            case .networkError:
                return "Kunne ikke koble til tjenesten. Prøv igjen."
            case .decodingError:
                return "Kunne ikke tolke svar fra server"
            case .serverError(let code):
                return "Server feil: \(code)"
            case .backendError:
                return "Tjenesten kunne ikke fullføre forespørselen. Prøv igjen."
            case .backendNotConfigured:
                return "Backend ikke konfigurert"
            case .batchLimitExceeded(let limit):
                return "For mange endringer i én forespørsel (maks \(limit))"
            case .payloadTooLarge(let limit):
                return "Endringen er for stor til å sendes (maks \(limit) byte)"
            case .missingAccessToken:
                return "Du må være innlogget for å synkronisere"
            case .sessionExpired:
                return "Økten din er utløpt. Logg inn på nytt."
            case .credentialPersistenceFailed:
                return "Den fornyede innloggingen kunne ikke lagres sikkert. Logg inn på nytt."
            case .rateLimited(let seconds):
                if let seconds {
                    return "Tjenesten ber oss vente. Prøv igjen om ca. \(seconds) sekunder."
                }
                return "Tjenesten ber oss vente litt før neste forsøk."
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
    
    func signupEmail(email: String, password: String) async throws -> (User, AuthTokens) {
        let url = try endpointURL("/auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let result = try await httpClient.send(request, timeout: 30)
        
        try requireBackendSuccess(data: result.data, response: result.response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let authResponse = try decoder.decode(AuthResponse.self, from: result.data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: authResponse.auth_provider,
            createdAt: authResponse.created_at
        )
        
        return (user, authResponse.tokens)
    }

    func loginApple(identityToken: String, authorizationCode: String?, nonce: String) async throws -> (User, AuthTokens) {
        let url = try endpointURL("/auth/apple")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = ["identity_token": identityToken, "nonce": nonce]
        if let authorizationCode { body["authorization_code"] = authorizationCode }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let result = try await httpClient.send(request, timeout: 30)
        try requireBackendSuccess(data: result.data, response: result.response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let authResponse = try decoder.decode(AuthResponse.self, from: result.data)
        return (authResponse.user, authResponse.tokens)
    }
    
    func loginEmail(email: String, password: String) async throws -> (User, AuthTokens) {
        let url = try endpointURL("/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let result = try await httpClient.send(request, timeout: 30)
        
        try requireBackendSuccess(data: result.data, response: result.response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let authResponse = try decoder.decode(AuthResponse.self, from: result.data)
        
        let user = User(
            id: authResponse.user_id,
            email: authResponse.email,
            firstName: authResponse.first_name,
            lastName: authResponse.last_name,
            authProvider: authResponse.auth_provider,
            createdAt: authResponse.created_at
        )
        
        return (user, authResponse.tokens)
    }

    func revokeRefreshToken(_ refreshToken: String) async throws {
        let url = try endpointURL("/auth/logout")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refresh_token: refreshToken))
        let result = try await httpClient.send(request, timeout: 10)
        try requireBackendSuccess(data: result.data, response: result.response)
    }

    func deleteAccount() async throws -> AccountDeletionReceipt {
        guard let url = URL(string: "\(baseURL)/user") else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let result = try await sendAuthorized(request, timeout: 30)
        try requireBackendSuccess(data: result.data, response: result.response)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AccountDeletionReceipt.self, from: result.data)
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
        let url = try endpointURL("/sync/events")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
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
        
        let result = try await sendAuthorized(request, timeout: 30)
        try requireBackendSuccess(data: result.data, response: result.response)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(UploadEventsResponse.self, from: result.data)
        let rejected = decoded.rejected?.map {
            RejectedEvent(eventId: $0.eventId, code: $0.code, message: $0.message)
        } ?? []
        
        #if DEBUG
        if !rejected.isEmpty {
            // Keep diagnostics aggregate-only: payloads and identifiers are sensitive.
            print("Sync rejected \(rejected.count) event(s)")
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
        
        let result = try await httpClient.send(request, timeout: 10)
        let data = result.data
        let httpResponse = result.response
        
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
            let calories_per_100g: Float
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

    func searchProductsByNameOpenFoodFacts(_ query: String, scope: FoodSearchScope = .norway) async throws -> [Product] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let host = scope == .norway ? "no.openfoodfacts.org" : "world.openfoodfacts.org"
        var components = URLComponents(string: "https://\(host)/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: trimmed),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(
                name: "fields",
                value: "code,product_name,brands,categories,nutriscore_grade,nutriscore_version,nutriscore,nova_group,nova_groups_markers,ingredients_text,ingredients_text_nb,ingredients_text_no,image_front_url,serving_size,serving_quantity,product_quantity,product_quantity_unit,nutrition_data_per,nutriments,last_modified_t,rev,schema_version,data_quality_errors_tags,data_quality_warnings_tags"
            )
        ]
        guard let url = components?.url else { throw APIError.invalidURL }

        let data = try await openFoodFactsData(from: url)
        return try await BackgroundWork.run { try OpenFoodFactsParser.search(data) }
    }
    
    func searchProductByBarcodeOpenFoodFacts(_ ean: String) async throws -> Product {
        let fields = [
            "code", "product_name", "brands", "categories", "image_front_url",
            "nutriscore_grade", "nutriscore_version", "nutriscore", "nova_group", "nova_groups_markers", "ingredients_text", "ingredients_text_nb", "ingredients_text_no",
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
        return try await BackgroundWork.run { try OpenFoodFactsParser.barcode(data, ean: ean) }
    }

    private func openFoodFactsData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue(openFoodFactsUserAgent, forHTTPHeaderField: "User-Agent")

        for attempt in 0...catalogRetryLimit {
            do {
                let result = try await httpClient.send(request, timeout: 10)
                let statusCode = result.response.statusCode
                if statusCode == 429 {
                    let retryAfter = result.response.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
                    if attempt < catalogRetryLimit,
                       RequestBackoff.shouldRetryRateLimit(retryAfterSeconds: retryAfter) {
                        try await sleep(RequestBackoff.delay(attempt: attempt, retryAfterSeconds: retryAfter))
                        continue
                    }
                    throw APIError.rateLimited(retryAfterSeconds: retryAfter)
                }
                if (500...599).contains(statusCode), attempt < catalogRetryLimit {
                    try await sleep(RequestBackoff.delay(attempt: attempt))
                    continue
                }
                guard (200...299).contains(statusCode) else {
                    throw APIError.serverError(statusCode)
                }
                return result.data
            } catch let error as HTTPClientError {
                guard attempt < catalogRetryLimit else { throw error }
                try await sleep(RequestBackoff.delay(attempt: attempt))
            }
        }
        throw APIError.networkError("Produktdatabasen svarte ikke")
    }

    private var openFoodFactsUserAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        return "MatLogg/\(version) (mailto:nithusank.2002@gmail.com)"
    }

    private func requireBackendSuccess(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Ugyldig respons")
        }
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            throw APIError.rateLimited(retryAfterSeconds: retryAfter)
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

    private func sendAuthorized(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        guard let token = authSessionStore?.getStoredToken() ?? accessTokenProvider(), !token.isEmpty else {
            throw APIError.missingAccessToken
        }
        var authorized = request
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let initial = try await httpClient.send(authorized, timeout: timeout)
        guard initial.response.statusCode == 401 else { return initial }
        guard let authSessionStore,
              let refreshToken = authSessionStore.getStoredRefreshToken(),
              !refreshToken.isEmpty else {
            invalidateSession()
            throw APIError.sessionExpired
        }

        do {
            let tokens = try await refreshCoordinator.refresh { [weak self] in
                guard let self else { throw APIError.sessionExpired }
                let refreshed = try await self.refreshTokens(using: refreshToken)
                guard authSessionStore.storeTokens(refreshed) else {
                    self.invalidateSession()
                    throw APIError.credentialPersistenceFailed
                }
                return refreshed
            }
            authorized.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            let retried = try await httpClient.send(authorized, timeout: timeout)
            if retried.response.statusCode == 401 || retried.response.statusCode == 403 {
                invalidateSession()
                throw APIError.sessionExpired
            }
            return retried
        } catch let error as APIError {
            if case .backendError(let statusCode, _, _) = error,
               statusCode == 401 || statusCode == 403 {
                invalidateSession()
                throw APIError.sessionExpired
            }
            throw error
        }
    }

    private func refreshTokens(using refreshToken: String) async throws -> AuthTokens {
        let url = try endpointURL("/auth/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshRequest(refresh_token: refreshToken))
        let result = try await httpClient.send(request, timeout: 30)
        try requireBackendSuccess(data: result.data, response: result.response)
        return try JSONDecoder().decode(TokenResponse.self, from: result.data).tokens
    }

    private func invalidateSession() {
        _ = authSessionStore?.clearStoredCredentials()
        NotificationCenter.default.post(name: .authSessionExpired, object: nil)
    }

}

nonisolated private enum OpenFoodFactsParser {
    static func search(_ data: Data) throws -> [Product] {
        let response = try JSONDecoder().decode(OpenFoodFactsSearchResponse.self, from: data)
        return response.products.compactMap {
            makeOpenFoodFactsProduct($0, barcode: $0.code, requiresCompleteMacros: true)
        }
    }

    static func barcode(_ data: Data, ean: String) throws -> Product {
        let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        guard response.status == "success", let product = response.product else {
            throw APIService.APIError.serverError(404)
        }
        guard let mapped = makeOpenFoodFactsProduct(product, barcode: product.code ?? ean, requiresCompleteMacros: true) else {
            throw APIService.APIError.incompleteProductData
        }
        return mapped
    }

    private static func makeOpenFoodFactsProduct(
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
            identity: barcode ?? name,
            servingSize: product.servingSize,
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
            caloriesPer100g: Float(completeNutrition.energyKcal),
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
            nutriScoreInfo: product.nutriScoreInfo,
            processingInfo: product.processingInfo,
            dataQualityWarnings: (product.dataQualityErrors ?? []) + (product.dataQualityWarnings ?? [])
        )
    }

    private static func validatedNutrition(_ nutriments: OpenFoodFactsNutriments?) -> CompleteNutrition? {
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
    
    private static func buildServingOptions(
        identity: String,
        servingSize: String?,
        productQuantity: Double?,
        productQuantityUnit: String?
    ) -> [ServingOption]? {
        var options: [ServingOption] = []
        func add(label: String, amount: Double, unit: AmountUnit, kind: ServingKind,
                 shortLabel: String, suggested: Bool) {
            guard amount.isFinite, amount > 0, amount <= 10_000 else { return }
            options.append(ServingOption(
                id: Product.catalogID(source: "off-serving", externalID: "\(identity)|\(label)|\(amount)|\(unit.rawValue)|\(kind.rawValue)"),
                label: label, grams: amount, unit: unit, source: .openFoodFacts,
                isDefaultSuggestion: suggested, kind: kind, shortLabel: shortLabel))
        }
        if let servingSize, let parsed = parseAmount(from: servingSize) {
            let label = servingSize.trimmingCharacters(in: .whitespacesAndNewlines)
            let short = ServingOption.documentedLabel(label)
            add(label: label, amount: parsed.value, unit: parsed.unit,
                kind: short == "porsjon" ? .portion : .piece, shortLabel: short, suggested: true)
        }
        // serving_quantity alone has no explicit serving unit; package units cannot establish it.

        if let quantity = parseQuantity(productQuantity: productQuantity, unit: productQuantityUnit) {
            add(label: "Hel pakke (\(formatGrams(quantity.value)) \(quantity.unit.rawValue))",
                amount: quantity.value, unit: quantity.unit, kind: .package,
                shortLabel: "hel pakke", suggested: false)
        }
        guard !options.isEmpty else { return nil }
        let unit = options.first?.amountUnit ?? .grams
        options.append(ServingOption(
            id: Product.catalogID(source: "off-serving", externalID: "100-\(unit.rawValue)"),
            label: "100 \(unit.rawValue)", grams: 100, unit: unit,
            source: .heuristic, kind: .baseAmount))
        return options
    }
    
    private static func parseAmount(from text: String) -> (value: Double, unit: AmountUnit)? {
        let pattern = #"(?<![0-9.,+\-])([0-9]+(?:[.,][0-9]+)?)\s*(ml|g)\b"#
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
    
    private static func parseQuantity(productQuantity: Double?, unit: String?) -> (value: Double, unit: AmountUnit)? {
        guard let productQuantity, productQuantity > 0,
              let amountUnit = amountUnit(from: unit) else { return nil }
        return (productQuantity, amountUnit)
    }

    private static func amountUnit(from rawValue: String?) -> AmountUnit? {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g", "gram", "grams": return .grams
        case "ml", "milliliter", "milliliters", "millilitres": return .milliliters
        default: return nil
        }
    }

    private static func nutritionBasis(nutritionDataPer: String?, productQuantityUnit: String?) -> NutritionBasis {
        let normalized = nutritionDataPer?.lowercased().replacingOccurrences(of: " ", with: "")
        if normalized == "100ml" { return .per100ml }
        if normalized == nil, amountUnit(from: productQuantityUnit) == .milliliters { return .per100ml }
        return .per100g
    }
    
    private static func formatGrams(_ grams: Double) -> String {
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
    let refresh_token: String?

    var tokens: AuthTokens { AuthTokens(accessToken: token, refreshToken: refresh_token) }
    var user: User {
        User(
            id: user_id,
            email: email,
            firstName: first_name,
            lastName: last_name,
            authProvider: auth_provider,
            createdAt: created_at
        )
    }
}

private struct RefreshRequest: Encodable {
    let refresh_token: String
}

private struct TokenResponse: Decodable {
    let token: String
    let refresh_token: String?

    var tokens: AuthTokens { AuthTokens(accessToken: token, refreshToken: refresh_token) }
}

actor TokenRefreshCoordinator {
    private var inFlight: Task<AuthTokens, Error>?

    func refresh(operation: @escaping () async throws -> AuthTokens) async throws -> AuthTokens {
        if let inFlight { return try await inFlight.value }
        let task = Task { try await operation() }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }
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

nonisolated private struct OpenFoodFactsResponse: Codable {
    let status: String
    let product: OpenFoodFactsProduct?
}

nonisolated private struct OpenFoodFactsSearchResponse: Codable {
    let products: [OpenFoodFactsProduct]
}

nonisolated private struct OpenFoodFactsProduct: Codable {
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

    // Optional enrichment must never prevent decoding a usable product.
    private var nutriScoreGrade: String? = nil
    private var nutriScoreVersion: String? = nil
    private var nutriScoreCalculations: [String: OFFNutriScoreCalculation]? = nil
    private var novaGroup: Int? = nil
    private var novaMarkers: [String: [[String]]] = [:]
    private var ingredientsText: String? = nil
    private var ingredientsNB: String? = nil
    private var ingredientsNO: String? = nil

    var nutriScoreInfo: ProductNutriScoreInfo? {
        let selected = nutriScoreVersion == "2023" ? nutriScoreCalculations?["2023"] : nil
        let matches = selected?.grade?.uppercased() == nutriScoreGrade?.uppercased()
        return ProductNutriScoreInfo(grade: nutriScoreGrade, version: nutriScoreVersion,
                                    calculation: matches ? selected?.mapped : nil)
    }

    var processingInfo: ProductProcessingInfo {
        let ingredients = [ingredientsNB, ingredientsNO, ingredientsText]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return ProductProcessingInfo(novaGroup: novaGroup.flatMap { (1...4).contains($0) ? $0 : nil },
                                     markers: novaMarkers, ingredients: ingredients)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        productName = try c.decodeIfPresent(String.self, forKey: .productName)
        brands = try c.decodeIfPresent(String.self, forKey: .brands)
        categories = try c.decodeIfPresent(String.self, forKey: .categories)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        servingSize = try c.decodeIfPresent(String.self, forKey: .servingSize)
        servingQuantity = try c.decodeIfPresent(FlexibleDouble.self, forKey: .servingQuantity)
        productQuantity = try c.decodeIfPresent(FlexibleDouble.self, forKey: .productQuantity)
        productQuantityUnit = try c.decodeIfPresent(String.self, forKey: .productQuantityUnit)
        nutriments = try c.decodeIfPresent(OpenFoodFactsNutriments.self, forKey: .nutriments)
        nutritionDataPer = try c.decodeIfPresent(String.self, forKey: .nutritionDataPer)
        lastModifiedTimestamp = try c.decodeIfPresent(Int.self, forKey: .lastModifiedTimestamp)
        revision = try c.decodeIfPresent(Int.self, forKey: .revision)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        dataQualityErrors = try c.decodeIfPresent([String].self, forKey: .dataQualityErrors)
        dataQualityWarnings = try c.decodeIfPresent([String].self, forKey: .dataQualityWarnings)
        nutriScoreGrade = try? c.decode(String.self, forKey: .nutriScoreGrade)
        nutriScoreVersion = try? c.decode(String.self, forKey: .nutriScoreVersion)
        nutriScoreCalculations = try? c.decode([String: OFFNutriScoreCalculation].self, forKey: .nutriScoreCalculations)
        novaGroup = try? c.decode(Int.self, forKey: .novaGroup)
        novaMarkers = (try? c.decode([String: [[String]]].self, forKey: .novaMarkers)) ?? [:]
        ingredientsText = try? c.decode(String.self, forKey: .ingredientsText)
        ingredientsNB = try? c.decode(String.self, forKey: .ingredientsNB)
        ingredientsNO = try? c.decode(String.self, forKey: .ingredientsNO)
    }

    enum CodingKeys: String, CodingKey {
        case code
        case nutriScoreGrade = "nutriscore_grade"
        case nutriScoreVersion = "nutriscore_version"
        case nutriScoreCalculations = "nutriscore"
        case novaGroup = "nova_group"
        case novaMarkers = "nova_groups_markers"
        case ingredientsText = "ingredients_text"
        case ingredientsNB = "ingredients_text_nb"
        case ingredientsNO = "ingredients_text_no"
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

nonisolated private struct CompleteNutrition {
    let energyKcal: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
}

nonisolated private struct OpenFoodFactsNutriments: Codable {
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

enum SyncDeviceIdentity {
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

nonisolated private struct FlexibleDouble: Codable {
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

nonisolated private struct OFFNutriScoreCalculation: Codable {
    let grade: String?
    let estimated: Int?
    let preparation: String?
    let nutriscore_computed: Int?
    let data: Details?

    struct Details: Codable {
        let components: Components?
        let positive_points: Int?
        let positive_points_max: Int?
        let negative_points: Int?
        let negative_points_max: Int?
        let is_beverage: Int?
        let count_proteins: Int?
        let count_proteins_reason: String?
    }
    struct Components: Codable {
        let positive: [NutriScoreComponent]?
        let negative: [NutriScoreComponent]?
    }

    var mapped: NutriScoreCalculation? {
        guard nutriscore_computed == 1, let data, let components = data.components else { return nil }
        var result = NutriScoreCalculation(positive: components.positive ?? [], negative: components.negative ?? [],
            positivePoints: data.positive_points, positiveMaximum: data.positive_points_max,
            negativePoints: data.negative_points, negativeMaximum: data.negative_points_max,
            estimated: estimated == 1, preparation: preparation,
            proteinExclusionReason: data.count_proteins == 0 ? data.count_proteins_reason : nil)
        if data.is_beverage == 1 { result.nutritionBasis = .per100ml }
        else if data.is_beverage == 0 { result.nutritionBasis = .per100g }
        return result
    }
}
