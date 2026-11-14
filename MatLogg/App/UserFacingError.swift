import Foundation
import Supabase

/// Presentation only. Never changes retry, authorization or persistence decisions.
nonisolated enum UserFacingError {
    static func message(_ error: Error, fallback: String) -> String {
        if let auth = error as? AuthError {
            return authMessage(code: auth.errorCode.rawValue, fallback: fallback)
        }
        if let account = error as? AccountAuthError { return account.errorDescription ?? fallback }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "Ingen nettforbindelse. Sjekk forbindelsen og prøv igjen."
            case .timedOut: return "Tjenesten svarte ikke i tide. Prøv igjen."
            default: return fallback
            }
        }
        if let api = error as? APIService.APIError {
            switch api {
            case .sessionExpired, .missingAccessToken:
                return "Økten din er utløpt. Logg inn på nytt."
            case .rateLimited:
                return "For mange forsøk. Vent litt og prøv igjen."
            case .incompleteProductData:
                return "Produktet mangler komplette næringsverdier per 100 g eller 100 ml."
            case .credentialPersistenceFailed:
                return "Innloggingen kunne ikke lagres sikkert. Logg inn på nytt."
            default: return fallback
            }
        }
        return fallback
    }

    static func authMessage(code: String, fallback: String) -> String {
        switch code {
        case "invalid_credentials": return "E-post eller passord er feil. Prøv igjen."
        case "email_not_confirmed": return "Bekreft e-postadressen din før du logger inn."
        case "session_expired", "session_not_found", "refresh_token_not_found", "refresh_token_already_used":
            return "Økten din er utløpt. Logg inn på nytt."
        case "over_request_rate_limit", "over_email_send_rate_limit":
            return "For mange forsøk. Vent litt og prøv igjen."
        case "weak_password": return "Passordet oppfyller ikke kravene. Velg et sterkere passord."
        default: return fallback
        }
    }
}
