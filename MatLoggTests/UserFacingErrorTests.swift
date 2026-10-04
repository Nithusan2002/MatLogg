import Foundation
import Testing
@testable import MatLogg

struct UserFacingErrorTests {
    @Test func unknownErrorsNeverExposeRawDetails() {
        let secret = "English failure: token=secret user@example.com"
        let error = NSError(domain: "server", code: 500, userInfo: [NSLocalizedDescriptionKey: secret])
        #expect(UserFacingError.message(error, fallback: "Kunne ikke lagre.") == "Kunne ikke lagre.")
        #expect(UserFacingError.message(APIService.APIError.backendError(statusCode: 400, code: "unknown", message: secret), fallback: "Prøv igjen.") == "Prøv igjen.")
        #expect(APIService.APIError.networkError(secret).errorDescription?.contains(secret) == false)
        #expect(APIService.APIError.backendError(statusCode: 500, code: nil, message: secret).errorDescription?.contains(secret) == false)
    }

    @Test func knownAuthCodesAndNetworkErrorsHaveNorwegianActions() {
        #expect(UserFacingError.authMessage(code: "invalid_credentials", fallback: "Ukjent") == "E-post eller passord er feil. Prøv igjen.")
        #expect(UserFacingError.authMessage(code: "email_not_confirmed", fallback: "Ukjent").contains("Bekreft"))
        #expect(UserFacingError.authMessage(code: "session_expired", fallback: "Ukjent").contains("Logg inn"))
        #expect(UserFacingError.authMessage(code: "new_code", fallback: "Prøv igjen.") == "Prøv igjen.")
        #expect(UserFacingError.message(URLError(.notConnectedToInternet), fallback: "Ukjent").contains("nettforbindelse"))
        #expect(UserFacingError.message(URLError(.timedOut), fallback: "Ukjent").contains("i tide"))
    }
}
