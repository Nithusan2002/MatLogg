import Foundation
import Supabase

struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String
    let callbackURL: URL

    static func load(bundle: Bundle = .main) throws -> SupabaseConfiguration {
        guard let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              !urlString.contains("$("),
              let url = URL(string: urlString),
              url.scheme == "https" || url.host == "127.0.0.1" || url.host == "localhost",
              let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !key.isEmpty,
              !key.contains("$("),
              let callbackString = bundle.object(forInfoDictionaryKey: "SUPABASE_AUTH_CALLBACK_URL") as? String,
              let callbackURL = URL(string: callbackString),
              callbackURL.scheme == "matlogg",
              callbackURL.host == "auth",
              callbackURL.path == "/callback" else {
            throw AccountAuthError.configurationMissing
        }
        return SupabaseConfiguration(url: url, publishableKey: key, callbackURL: callbackURL)
    }
}

final class SupabaseService: AccountAuthRepository, SyncAPIClient, NutritionLabelAIService, SharedProductCatalogService {
    private let client: SupabaseClient
    private let callbackURL: URL
    private let dateFormatter: ISO8601DateFormatter

    init(configuration: SupabaseConfiguration) {
        callbackURL = configuration.callbackURL
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        client = SupabaseClient(
            supabaseURL: configuration.url,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: AuthClient.Configuration.defaultLocalStorage,
                    redirectToURL: configuration.callbackURL,
                    flowType: .pkce,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    func restoreSession() async -> User? {
        guard let session = try? await client.auth.session,
              !session.isExpired else { return nil }
        return Self.mapUser(session.user)
    }

    func signIn(email: String, password: String) async throws -> User {
        Self.mapUser(try await client.auth.signIn(email: email, password: password).user)
    }

    func signUp(email: String, password: String) async throws -> AccountRegistrationResult {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: callbackURL
        )
        if let session = response.session {
            return .authenticated(Self.mapUser(session.user))
        }
        return .pendingEmailVerification(email: email)
    }

    func resendEmailVerification(to email: String) async throws {
        try await client.auth.resend(email: email, type: .signup, emailRedirectTo: callbackURL)
    }

    func signInWithApple(identityToken: String, nonce: String) async throws -> User {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: identityToken,
                nonce: nonce
            )
        )
        return Self.mapUser(session.user)
    }

    func handleAuthCallback(_ url: URL) async throws -> User {
        Self.mapUser(try await client.auth.session(from: url).user)
    }

    func signOut() async throws {
        try await client.auth.signOut(scope: .local)
    }

    func deleteAccount() async throws -> AccountDeletionReceipt {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await client.functions.invoke(
            "delete-account",
            options: .init(body: EmptyRequest()),
            decoder: decoder
        )
    }

    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        guard events.count <= 50 else { throw APIService.APIError.batchLimitExceeded(50) }
        guard !events.contains(where: { $0.payload.count > 64 * 1024 }) else {
            throw APIService.APIError.payloadTooLarge(64 * 1024)
        }
        let request = SupabaseSyncRequest(
            deviceId: SyncDeviceIdentity.id,
            clientTime: dateFormatter.string(from: Date()),
            events: events.map {
                SupabaseSyncEvent(
                    eventId: $0.eventId,
                    type: $0.type,
                    createdAt: dateFormatter.string(from: $0.createdAt),
                    entityId: $0.entityId,
                    schemaVersion: $0.schemaVersion,
                    payload: $0.payload.base64EncodedString()
                )
            }
        )
        do {
            let response: SupabaseSyncResponse = try await client.functions.invoke(
                "sync-events",
                options: .init(body: request)
            )
            return APIService.UploadResult(
                ackedEventIds: response.ackedEventIds,
                rejected: response.rejected.map {
                    APIService.RejectedEvent(eventId: $0.eventId, code: $0.code, message: $0.message)
                }
            )
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                let response = try? JSONDecoder().decode(SupabaseFunctionError.self, from: data)
                if code == 429 { throw APIService.APIError.rateLimited(retryAfterSeconds: 60) }
                throw APIService.APIError.backendError(
                    statusCode: code,
                    code: response?.code,
                    message: response?.message ?? "Serverfeil (\(code))"
                )
            case .relayError:
                throw APIService.APIError.networkError("Kunne ikke kontakte synktjenesten")
            }
        }
    }

    func extract(assetID: UUID, imageData: Data, localOCRText: String, language: String) async throws -> NutritionExtraction {
        guard imageData.count <= LocalProductImageStore.maximumBytes else { throw ProductImageError.tooLarge }
        do {
            let upload: ProductUploadResponse = try await client.functions.invoke(
                "create-product-upload",
                options: .init(body: ProductUploadRequest(
                    assetId: assetID,
                    kind: "nutrition_label",
                    contentType: "image/jpeg",
                    byteSize: imageData.count
                ))
            )
            guard let uploadURL = URL(string: upload.signedUrl),
                  uploadURL.scheme == "https" || uploadURL.host == "127.0.0.1" || uploadURL.host == "localhost" else {
                throw ProductAIError.invalidResponse
            }
            var request = URLRequest(url: uploadURL)
            request.httpMethod = "PUT"
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
            let (_, uploadResponse) = try await URLSession.shared.upload(for: request, from: imageData)
            guard let httpResponse = uploadResponse as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw ProductAIError.unavailable
            }
            let response: NutritionExtractionResponse = try await client.functions.invoke(
                "extract-nutrition-label",
                options: .init(body: NutritionExtractionRequest(
                    assetId: assetID,
                    localOCRText: localOCRText,
                    language: language
                ))
            )
            return response.extraction
        } catch let error as ProductAIError {
            throw error
        } catch let error as FunctionsError {
            switch error {
            case .httpError(let code, let data):
                let response = try? JSONDecoder().decode(SupabaseFunctionError.self, from: data)
                if response?.code == "AI_REFUSAL" { throw ProductAIError.refused }
                if code == 422 { throw ProductAIError.refused }
                throw ProductAIError.unavailable
            case .relayError:
                throw ProductAIError.unavailable
            }
        } catch {
            throw ProductAIError.unavailable
        }
    }

    func searchSharedCatalog(query: String) async throws -> [Product] {
        let response: SharedCatalogLookupResponse = try await client.functions.invoke(
            "catalog-lookup",
            options: .init(body: SharedCatalogLookupRequest(query: query))
        )
        return response.products.map { item in
            Product(
                id: item.id,
                name: item.name,
                brand: item.brand,
                barcodeEan: item.barcode,
                source: "shared",
                kind: .packaged,
                caloriesPer100g: Float(item.nutrients.kcal),
                proteinGPer100g: Float(item.nutrients.protein),
                carbsGPer100g: Float(item.nutrients.carbs),
                fatGPer100g: Float(item.nutrients.fat),
                saturatedFatGPer100g: item.nutrients.saturatedFat.map(Float.init),
                sugarGPer100g: item.nutrients.sugars.map(Float.init),
                fiberGPer100g: item.nutrients.fiber.map(Float.init),
                saltGPer100g: item.nutrients.salt.map(Float.init),
                sodiumMgPer100g: item.nutrients.sodium.map { Int(($0 * 1_000).rounded()) },
                imageUrl: item.frontImageURL,
                nutritionSource: .user,
                imageSource: item.frontImageURL == nil ? .none : .user,
                verificationStatus: item.status == "verified" ? .verified : .unverified,
                isVerified: item.status == "verified",
                externalID: item.id.uuidString,
                nutritionBasis: item.nutritionBasis,
                sourceUpdatedAt: item.updatedAt.flatMap(dateFormatter.date(from:)),
                fetchedAt: Date()
            )
        }
    }

    nonisolated private static func mapUser(_ user: Supabase.User) -> User {
        let fullName = user.userMetadata["full_name"]?.stringValue
            ?? user.userMetadata["name"]?.stringValue ?? ""
        let nameParts = fullName.split(whereSeparator: { $0.isWhitespace })
        let provider = user.identities?.contains(where: { $0.provider == "apple" }) == true ? "apple" : "email"
        return User(
            id: user.id,
            email: user.email ?? "",
            firstName: user.userMetadata["given_name"]?.stringValue
                ?? user.userMetadata["first_name"]?.stringValue
                ?? nameParts.first.map(String.init) ?? "",
            lastName: user.userMetadata["family_name"]?.stringValue
                ?? user.userMetadata["last_name"]?.stringValue
                ?? nameParts.dropFirst().joined(separator: " "),
            authProvider: provider,
            createdAt: user.createdAt
        )
    }
}

final class UnavailableAccountAuthRepository: AccountAuthRepository {
    func restoreSession() async -> User? { nil }
    func signIn(email: String, password: String) async throws -> User { throw AccountAuthError.configurationMissing }
    func signUp(email: String, password: String) async throws -> AccountRegistrationResult { throw AccountAuthError.configurationMissing }
    func resendEmailVerification(to email: String) async throws { throw AccountAuthError.configurationMissing }
    func signInWithApple(identityToken: String, nonce: String) async throws -> User { throw AccountAuthError.configurationMissing }
    func handleAuthCallback(_ url: URL) async throws -> User { throw AccountAuthError.configurationMissing }
    func signOut() async throws {}
    func deleteAccount() async throws -> AccountDeletionReceipt { throw AccountAuthError.configurationMissing }
}

struct UnavailableSyncAPIClient: SyncAPIClient {
    func uploadEvents(_ events: [SyncEvent]) async throws -> APIService.UploadResult {
        throw APIService.APIError.backendNotConfigured
    }
}

nonisolated private struct EmptyRequest: Encodable, Sendable {}

nonisolated private struct SupabaseSyncRequest: Encodable, Sendable {
    let deviceId: UUID
    let clientTime: String
    let events: [SupabaseSyncEvent]
}

nonisolated private struct SupabaseSyncEvent: Encodable, Sendable {
    let eventId: UUID
    let type: String
    let createdAt: String
    let entityId: String?
    let schemaVersion: Int
    let payload: String
}

nonisolated private struct SupabaseSyncResponse: Decodable, Sendable {
    let ackedEventIds: [UUID]
    let rejected: [SupabaseRejectedEvent]
}

nonisolated private struct SupabaseRejectedEvent: Decodable, Sendable {
    let eventId: UUID
    let code: String
    let message: String
}

nonisolated private struct SupabaseFunctionError: Decodable, Sendable {
    let code: String?
    let message: String?
}

nonisolated private struct ProductUploadRequest: Encodable, Sendable {
    let assetId: UUID
    let kind: String
    let contentType: String
    let byteSize: Int
}

nonisolated private struct ProductUploadResponse: Decodable, Sendable {
    let assetId: UUID
    let path: String
    let token: String
    let signedUrl: String
}

nonisolated private struct NutritionExtractionRequest: Encodable, Sendable {
    let assetId: UUID
    let localOCRText: String
    let language: String
}

nonisolated private struct NutritionExtractionResponse: Decodable, Sendable {
    let extraction: NutritionExtraction
}

nonisolated private struct SharedCatalogLookupRequest: Encodable, Sendable { let query: String }
nonisolated private struct SharedCatalogLookupResponse: Decodable, Sendable { let products: [SharedCatalogProduct] }
nonisolated private struct SharedCatalogProduct: Decodable, Sendable {
    let id: UUID
    let name: String
    let brand: String?
    let barcode: String?
    let nutritionBasis: NutritionBasis
    let nutrients: SharedCatalogNutrients
    let frontImageURL: String?
    let status: String
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, brand, barcode, nutrients, status
        case nutritionBasis = "nutrition_basis"
        case frontImageURL = "front_image_url"
        case updatedAt = "updated_at"
    }
}
nonisolated private struct SharedCatalogNutrients: Decodable, Sendable {
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let saturatedFat: Double?
    let sugars: Double?
    let fiber: Double?
    let salt: Double?
    let sodium: Double?
}
