import Foundation
import OSLog

struct PublicProfileServiceImpl: PublicProfileManaging {
    private let session: URLSession
    private let baseURLOverride: URL?
    private let logger = Logger(subsystem: "com.recruitingcompass", category: "PublicProfile")

    init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
        self.session = session
        self.baseURLOverride = baseURLOverride
    }

    private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

    func fetchProfile(accessToken: String?) async throws -> PlayerProfile? {
        guard let baseURL, let token = accessToken, !token.isEmpty else { return nil }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/player/profile"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        guard !data.isEmpty else { return nil }
        return try JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    func updateProfile(_ payload: UpdateProfilePayload, accessToken: String?) async throws {
        guard let baseURL, let token = accessToken, !token.isEmpty else {
            throw PublicProfileAPIError.notConfigured
        }
        let csrf = try await fetchCSRFToken(baseURL: baseURL)
        var request = URLRequest(url: baseURL.appendingPathComponent("api/player/profile"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await session.data(for: request)
        try Self.mapStatus(response)
    }

    func fetchTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink? {
        guard let baseURL, let token = accessToken, !token.isEmpty else { return nil }
        let safeId = coachId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? coachId
        let url = baseURL.appendingPathComponent("api/player/profile/tracking-links").appendingPathComponent(safeId)
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        guard !data.isEmpty, (try? JSONSerialization.jsonObject(with: data)) is [String: Any] else { return nil }
        return try JSONDecoder().decode(ProfileTrackingLink.self, from: data)
    }

    func createTrackingLink(coachId: String, accessToken: String?) async throws -> ProfileTrackingLink {
        guard let baseURL, let token = accessToken, !token.isEmpty else {
            throw PublicProfileAPIError.notConfigured
        }
        let csrf = try await fetchCSRFToken(baseURL: baseURL)
        let safeId = coachId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? coachId
        let url = baseURL.appendingPathComponent("api/player/profile/tracking-links").appendingPathComponent(safeId)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(csrf, forHTTPHeaderField: "x-csrf-token")
        let (data, response) = try await session.data(for: request)
        try Self.mapStatus(response)
        return try JSONDecoder().decode(ProfileTrackingLink.self, from: data)
    }

    private static func mapStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw PublicProfileAPIError.server(-1) }
        switch http.statusCode {
        case 200...299: return
        case 401: throw PublicProfileAPIError.unauthorized
        case 403: throw PublicProfileAPIError.notMember
        case 409: throw PublicProfileAPIError.slugTaken
        case 422: throw PublicProfileAPIError.slugInvalid
        default: throw PublicProfileAPIError.server(http.statusCode)
        }
    }

    /// Fetches CSRF token from API (GET /api/csrf-token). Server sets csrf-token cookie;
    /// we read it and return the value so callers can send it in x-csrf-token header on mutating requests.
    /// URLSession will send the cookie automatically on subsequent requests to the same origin.
    private func fetchCSRFToken(baseURL: URL) async throws -> String {
        let url = baseURL.appendingPathComponent("api/csrf-token")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (_, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            logger.error("CSRF token request failed")
            throw NSError(domain: "PublicProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get CSRF token"])
        }

        // Cookie may be scoped to /api; ask for cookies that would be sent to an API path
        let apiURL = baseURL.appendingPathComponent("api")
        guard let cookies = HTTPCookieStorage.shared.cookies(for: apiURL),
              let csrfCookie = cookies.first(where: { $0.name == "csrf-token" }) else {
            logger.error("No csrf-token cookie in storage after GET /api/csrf-token")
            throw NSError(domain: "PublicProfileService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No CSRF token in response"])
        }

        return csrfCookie.value
    }
}
