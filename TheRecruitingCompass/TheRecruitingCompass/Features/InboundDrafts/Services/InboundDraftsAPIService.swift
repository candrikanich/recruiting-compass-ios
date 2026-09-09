import Foundation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "InboundDraftsAPIService")

enum InboundDraftsAPIError: Error, Sendable {
  case notConfigured
  case unauthorized
  case notFound
  /// 422 — a server-supplied, user-displayable message (e.g. "Invalid schoolId").
  case validation(String)
  case server(Int)
  case invalidResponse
}

/// Calls the web app's inbound-drafts endpoints. Mirrors `TimelineAPIService`'s
/// authed Bearer-token GET pattern; mobile clients are CSRF-exempt app-wide, so
/// POSTs skip the `x-csrf-token` dance `AthleteMessagesServiceImpl` needs.
final class InboundDraftsAPIService: InboundDraftsAPIManaging, Sendable {
  private let session: URLSession
  private let baseURLOverride: URL?

  init(session: URLSession = .shared, baseURLOverride: URL? = nil) {
    self.session = session
    self.baseURLOverride = baseURLOverride
  }

  private var baseURL: URL? { baseURLOverride ?? SupabaseConfig.apiBaseURL }

  func fetchPendingDrafts(accessToken: String?) async throws -> [InboundEmailDraft] {
    let data = try await request(path: "api/inbound-drafts", method: "GET", body: EmptyBody?.none, accessToken: accessToken)
    return try decode(InboundDraftsListResponse.self, from: data).drafts
  }

  func confirmDraft(
    id: String,
    schoolId: String?,
    coachId: String?,
    type: InteractionType,
    direction: Direction,
    occurredAt: Date,
    subject: String?,
    content: String?,
    accessToken: String?
  ) async throws -> InboundDraftConfirmResponse {
    let data = try await request(
      path: "api/inbound-drafts/\(id)/confirm",
      method: "POST",
      body: InboundDraftConfirmRequest(
        schoolId: schoolId,
        coachId: coachId,
        type: type,
        direction: direction,
        occurredAt: occurredAt,
        subject: subject,
        content: content
      ),
      accessToken: accessToken
    )
    return try decode(InboundDraftConfirmResponse.self, from: data)
  }

  func discardDraft(id: String, accessToken: String?) async throws -> InboundDraftDiscardResponse {
    let data = try await request(path: "api/inbound-drafts/\(id)/discard", method: "POST", body: EmptyBody?.none, accessToken: accessToken)
    return try decode(InboundDraftDiscardResponse.self, from: data)
  }

  func fetchForwardingAddress(accessToken: String?) async throws -> String {
    let data = try await request(path: "api/family/inbound-address", method: "GET", body: EmptyBody?.none, accessToken: accessToken)
    return try decode(InboundAddressResponse.self, from: data).address
  }

  // MARK: - Private

  private struct EmptyBody: Encodable {}

  private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try JSONDecoder().decode(type, from: data)
    } catch {
      logger.error("Failed to decode \(String(describing: type)): \(String(describing: error))")
      throw InboundDraftsAPIError.invalidResponse
    }
  }

  private func request<B: Encodable>(
    path: String,
    method: String,
    body: B?,
    accessToken: String?
  ) async throws -> Data {
    guard let baseURL else {
      logger.error("Inbound drafts API not configured (API_BASE_URL missing)")
      throw InboundDraftsAPIError.notConfigured
    }
    guard let token = accessToken, !token.isEmpty else {
      throw InboundDraftsAPIError.unauthorized
    }

    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    if let body {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(body)
    }

    let (data, response) = try await session.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      throw InboundDraftsAPIError.invalidResponse
    }
    guard (200...299).contains(http.statusCode) else {
      logger.error("\(path) returned \(http.statusCode)")
      switch http.statusCode {
      case 401, 403:
        throw InboundDraftsAPIError.unauthorized
      case 404:
        throw InboundDraftsAPIError.notFound
      case 422:
        throw InboundDraftsAPIError.validation(serverMessage(from: data) ?? "This draft can't be confirmed.")
      default:
        throw InboundDraftsAPIError.server(http.statusCode)
      }
    }
    return data
  }

  /// Nitro `createError` responses carry the developer-facing text in `statusMessage`
  /// (or `message`, depending on how the endpoint threw it).
  private func serverMessage(from data: Data) -> String? {
    struct ServerErrorBody: Decodable { let statusMessage: String?; let message: String? }
    guard let body = try? JSONDecoder().decode(ServerErrorBody.self, from: data) else { return nil }
    return body.statusMessage ?? body.message
  }
}
