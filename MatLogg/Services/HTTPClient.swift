import Foundation

struct HTTPClientResponse {
    let data: Data
    let response: HTTPURLResponse
}

enum HTTPClientError: LocalizedError, Equatable {
    case offline
    case timedOut
    case connectionLost
    case invalidResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "Ingen nettforbindelse. Sjekk forbindelsen og prøv igjen."
        case .timedOut:
            return "Tjenesten bruker for lang tid. Prøv igjen."
        case .connectionLost:
            return "Nettforbindelsen ble brutt. Prøv igjen."
        case .invalidResponse:
            return "Tjenesten returnerte et ugyldig svar."
        case .transport(let message):
            return message
        }
    }
}

protocol HTTPClientProtocol {
    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse
}

final class URLSessionHTTPClient: HTTPClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPClientResponse {
        var request = request
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPClientError.invalidResponse
            }
            return HTTPClientResponse(data: data, response: httpResponse)
        } catch let error as HTTPClientError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .internationalRoamingOff, .dataNotAllowed:
                throw HTTPClientError.offline
            case .timedOut:
                throw HTTPClientError.timedOut
            case .networkConnectionLost:
                throw HTTPClientError.connectionLost
            default:
                throw HTTPClientError.transport(error.localizedDescription)
            }
        } catch {
            throw HTTPClientError.transport(error.localizedDescription)
        }
    }
}

enum RequestBackoff {
    static func shouldRetryRateLimit(retryAfterSeconds: Int?) -> Bool {
        guard let retryAfterSeconds else { return true }
        return retryAfterSeconds <= 2
    }

    static func delay(attempt: Int, retryAfterSeconds: Int? = nil) -> TimeInterval {
        if let retryAfterSeconds {
            return max(0, TimeInterval(retryAfterSeconds))
        }
        let base = min(pow(2, Double(attempt)) * 0.25, 2)
        return base + Double.random(in: 0...0.15)
    }
}
