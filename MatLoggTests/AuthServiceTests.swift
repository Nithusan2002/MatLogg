import Foundation
import Security
import Testing
@testable import MatLogg

struct AuthServiceTests {
    @Test func storingExistingTokenUpdatesProtectedKeychainItem() {
        let keychain = KeychainClientSpy(updateStatus: errSecSuccess)
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        let stored = service.storeToken("updated-token")

        #expect(stored)
        #expect(keychain.addedAttributes == nil)
        #expect(keychain.updatedQuery?[kSecAttrService as String] as? String == "app.matlogg.auth")
        #expect(keychain.updatedQuery?[kSecAttrAccount as String] as? String == "ml_auth_token")
        #expect(keychain.updatedAttributes?[kSecValueData as String] as? Data == Data("updated-token".utf8))
        #expect(
            keychain.updatedAttributes?[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
    }

    @Test func storingNewTokenAddsProtectedKeychainItem() {
        let keychain = KeychainClientSpy(updateStatus: errSecItemNotFound, addStatus: errSecSuccess)
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        let stored = service.storeToken("new-token")

        #expect(stored)
        #expect(keychain.addedAttributes?[kSecAttrService as String] as? String == "app.matlogg.auth")
        #expect(keychain.addedAttributes?[kSecAttrAccount as String] as? String == "ml_auth_token")
        #expect(keychain.addedAttributes?[kSecValueData as String] as? Data == Data("new-token".utf8))
        #expect(
            keychain.addedAttributes?[kSecAttrAccessible as String] as? String
                == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
        )
    }

    @Test func keychainFailureDoesNotReportTokenAsStored() {
        let keychain = KeychainClientSpy(updateStatus: errSecAuthFailed)
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        #expect(!service.storeToken("token"))
        #expect(keychain.addedAttributes == nil)
    }

    @Test func tokenPairIsStoredTogetherAndCanBeReadBack() throws {
        let tokens = AuthTokens(accessToken: "access-token", refreshToken: "refresh-token")
        let encoded = try JSONEncoder().encode(tokens)
        let keychain = KeychainClientSpy(
            updateStatus: errSecSuccess,
            copyResults: [
                (errSecSuccess, encoded),
                (errSecSuccess, encoded),
            ]
        )
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        #expect(service.storeTokens(tokens))
        #expect(service.getStoredToken() == "access-token")
        #expect(service.getStoredRefreshToken() == "refresh-token")
        let storedData = try #require(keychain.updatedAttributes?[kSecValueData as String] as? Data)
        #expect(try JSONDecoder().decode(AuthTokens.self, from: storedData) == tokens)
    }

    @Test func readingTokenUsesScopedKeychainQuery() {
        let keychain = KeychainClientSpy(copyResults: [(errSecSuccess, Data("stored-token".utf8))])
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        let token = service.getStoredToken()

        #expect(token == "stored-token")
        #expect(keychain.copiedQuery?[kSecAttrService as String] as? String == "app.matlogg.auth")
        #expect(keychain.copiedQuery?[kSecAttrAccount as String] as? String == "ml_auth_token")
        #expect(keychain.copiedQuery?[kSecReturnData as String] as? Bool == true)
        #expect(keychain.copiedQuery?[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
    }

    @Test func readingLegacyTokenMigratesItToScopedProtectedItem() {
        let keychain = KeychainClientSpy(
            updateStatus: errSecItemNotFound,
            copyResults: [
                (errSecItemNotFound, nil),
                (errSecSuccess, Data("legacy-token".utf8))
            ]
        )
        let service = AuthService(defaults: isolatedDefaults(), keychain: keychain)

        let token = service.getStoredToken()

        #expect(token == "legacy-token")
        #expect(keychain.addedAttributes?[kSecAttrAccount as String] as? String == "ml_auth_token")
        #expect(keychain.deletedQueries.last?[kSecAttrAccount as String] as? String == "matlogg_auth")
    }

    @Test func clearingCredentialsReportsUnexpectedKeychainFailure() {
        let keychain = KeychainClientSpy(deleteStatuses: [errSecSuccess, errSecAuthFailed])
        let defaults = isolatedDefaults()
        defaults.set(Data("user".utf8), forKey: "ml_current_user")
        let service = AuthService(defaults: defaults, keychain: keychain)

        let cleared = service.clearStoredCredentials()

        #expect(!cleared)
        #expect(defaults.data(forKey: "ml_current_user") == nil)
        #expect(keychain.deletedQueries.count == 2)
    }

    @Test func localProfilePersistsUntilItIsConsumed() {
        let defaults = isolatedDefaults()
        let service = AuthService(defaults: defaults, keychain: KeychainClientSpy())

        let created = service.activateLocalProfile()
        let restored = service.getActiveLocalProfile()

        #expect(created.isLocalProfile)
        #expect(restored?.id == created.id)
        service.consumeLocalProfile()
        #expect(service.getActiveLocalProfile() == nil)
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AuthServiceTests.\(UUID().uuidString)")!
    }
}

private final class KeychainClientSpy: KeychainClient {
    var updateStatus: OSStatus
    var addStatus: OSStatus
    var copyResults: [(status: OSStatus, data: Data?)]
    var deleteStatuses: [OSStatus]

    private(set) var addedAttributes: [String: Any]?
    private(set) var updatedQuery: [String: Any]?
    private(set) var updatedAttributes: [String: Any]?
    private(set) var copiedQueries: [[String: Any]] = []
    private(set) var deletedQueries: [[String: Any]] = []

    var copiedQuery: [String: Any]? { copiedQueries.last }

    init(
        updateStatus: OSStatus = errSecSuccess,
        addStatus: OSStatus = errSecSuccess,
        copyResults: [(status: OSStatus, data: Data?)] = [(errSecItemNotFound, nil)],
        deleteStatuses: [OSStatus] = []
    ) {
        self.updateStatus = updateStatus
        self.addStatus = addStatus
        self.copyResults = copyResults
        self.deleteStatuses = deleteStatuses
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        addedAttributes = attributes
        return addStatus
    }

    func update(_ query: [String: Any], attributes: [String: Any]) -> OSStatus {
        updatedQuery = query
        updatedAttributes = attributes
        return updateStatus
    }

    func copyMatching(_ query: [String: Any]) -> (status: OSStatus, data: Data?) {
        copiedQueries.append(query)
        return copyResults.removeFirst()
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        deletedQueries.append(query)
        return deleteStatuses.isEmpty ? errSecSuccess : deleteStatuses.removeFirst()
    }
}
