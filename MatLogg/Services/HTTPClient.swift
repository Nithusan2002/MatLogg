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


/// A bounded policy for interactive name searches. Barcode requests retain their own policy.
enum ProductNameSearchRequest {
    static func send(
        _ request: URLRequest,
        client: any HTTPClientProtocol,
        budget: Duration = .seconds(15),
        sleep: @escaping (TimeInterval) async throws -> Void
    ) async throws -> HTTPClientResponse {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: budget)
        return try await withThrowingTaskGroup(of: HTTPClientResponse.self) { group in
            group.addTask {
                for attempt in 0..<3 {
                    try Task.checkCancellation()
                    let remaining = clock.now.duration(to: deadline)
                    guard remaining > .zero else { throw HTTPClientError.timedOut }
                    let parts = remaining.components
                    let timeout = min(10, Double(parts.seconds) + Double(parts.attoseconds) / 1e18)
                    let delay = attempt == 0 ? 1.0 : 3.0
                    do {
                        let result = try await client.send(request, timeout: timeout)
                        try Task.checkCancellation()
                        guard clock.now < deadline else { throw HTTPClientError.timedOut }
                        let status = result.response.statusCode
                        guard attempt < 2, [429, 500, 502, 503, 504].contains(status) else { return result }
                        // Respect both delta-seconds and HTTP-date Retry-After headers.
                        let header = result.response.value(forHTTPHeaderField: "Retry-After")
                        let requestedDelay = retryDelay(header, now: Date())
                        if header != nil && requestedDelay == nil { return result }
                        let wait = max(delay, requestedDelay ?? 0)
                        guard wait < 15, clock.now.advanced(by: .seconds(wait)) < deadline else { return result }
                        try await sleep(wait)
                    } catch let error as HTTPClientError {
                        try Task.checkCancellation()
                        guard attempt < 2, error == .timedOut || error == .connectionLost else { throw error }
                        guard clock.now.advanced(by: .seconds(delay)) < deadline else { throw error }
                        try await sleep(delay)
                    }
                }
                throw HTTPClientError.timedOut
            }
            group.addTask {
                try await clock.sleep(until: deadline)
                throw HTTPClientError.timedOut
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw CancellationError() }
            return result
        }
    }

    nonisolated static func retryDelay(_ header: String?, now: Date) -> TimeInterval? {
        guard let header else { return nil }
        if let seconds = TimeInterval(header), seconds.isFinite, seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: header) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
