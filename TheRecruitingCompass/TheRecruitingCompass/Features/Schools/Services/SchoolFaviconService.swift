import Foundation
import OSLog
import Supabase

nonisolated private let faviconLogger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SchoolFaviconService"
)

protocol SchoolFaviconManaging: Sendable {
  func fetchAndPersist(school: School) async
}

/// Fetches the best-quality favicon/logo for a school via the web app proxy
/// and writes it back to Supabase. All failures are silent — the school
/// functions normally without a favicon.
actor SchoolFaviconService: SchoolFaviconManaging {
  private let urlSession: URLSession
  private let baseURL: URL?

  init(urlSession: URLSession = .shared, baseURL: URL? = SupabaseConfig.apiBaseURL) {
    self.urlSession = urlSession
    self.baseURL = baseURL
  }

  func fetchAndPersist(school: School) async {
    guard let base = baseURL else {
      faviconLogger.debug("Favicon skipped: API_BASE_URL not configured")
      return
    }

    guard let domain = extractDomain(from: school.website), !domain.isEmpty else {
      faviconLogger.debug("Favicon skipped: no website configured for \(school.name)")
      return
    }

    guard let token = try? await SupabaseManager.shared.client.auth.session.accessToken,
          !token.isEmpty else {
      faviconLogger.debug("Favicon skipped: no auth token")
      return
    }

    guard var components = URLComponents(
      url: base.appendingPathComponent("api/schools/favicon"),
      resolvingAgainstBaseURL: false
    ) else { return }
    components.queryItems = [
      URLQueryItem(name: "schoolDomain", value: domain),
      URLQueryItem(name: "schoolId", value: school.id)
    ]
    guard let url = components.url else { return }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    do {
      let (data, response) = try await urlSession.data(for: request)
      guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
        faviconLogger.warning("Favicon fetch failed for \(school.name)")
        return
      }

      let decoded = try JSONDecoder().decode(FaviconResponse.self, from: data)
      guard let faviconUrl = decoded.faviconUrl, !faviconUrl.isEmpty else {
        faviconLogger.debug("No favicon found for \(school.name)")
        return
      }

      try await SupabaseManager.shared.client
        .from("schools")
        .update(["favicon_url": faviconUrl])
        .eq("id", value: school.id)
        .execute()

      faviconLogger.info("Favicon persisted for \(school.name): \(faviconUrl)")

    } catch {
      faviconLogger.warning("Favicon error for \(school.name): \(error.localizedDescription)")
    }
  }

  // MARK: - Domain Helpers

  private func extractDomain(from website: String?) -> String? {
    guard let raw = website, !raw.isEmpty else { return nil }
    var domain = raw.lowercased()
      .replacingOccurrences(of: "https://", with: "")
      .replacingOccurrences(of: "http://", with: "")
    if domain.hasPrefix("www.") { domain = String(domain.dropFirst(4)) }
    if let cut = domain.firstIndex(of: "/") { domain = String(domain[..<cut]) }
    if let cut = domain.firstIndex(of: "?") { domain = String(domain[..<cut]) }
    domain = domain.trimmingCharacters(in: .whitespaces)
    guard domain.contains("."), !domain.hasPrefix(".") else { return nil }
    return domain.isEmpty ? nil : domain
  }
}

// MARK: - Response Model

private struct FaviconResponse: Decodable, Sendable {
  let success: Bool
  let faviconUrl: String?
  let domain: String?
  let schoolId: String?
}
