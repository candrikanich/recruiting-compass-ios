import Auth
import Foundation
import OSLog
import Supabase

/// Calls the web API's family routes (server/api/family/**). Single place that owns auth, client
/// headers and mapping server errors to the message shown to the user — family features have no
/// Supabase edge functions to call.
struct FamilyAPIClient: Sendable {
  static let notConfiguredMessage = "App is not configured correctly. Please contact support."
  static let genericFailureMessage = "Something went wrong. Please try again."

  let session: URLSession
  let baseURL: URL?
  let tokenProvider: @Sendable () async throws -> String

  static func live(_ supabaseManager: SupabaseManager) -> FamilyAPIClient {
    FamilyAPIClient(
      session: .shared,
      baseURL: SupabaseConfig.apiBaseURL,
      tokenProvider: { try await supabaseManager.client.auth.session.accessToken }
    )
  }

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    let data = try await send("POST", "api/family/code/regenerate", body: ["familyId": familyId])
    return try JSONDecoder().decode(RegenerateFamilyCodeResponse.self, from: data)
  }

  func removeMember(memberId: String) async throws {
    _ = try await send("DELETE", "api/family/members/\(memberId)")
  }

  func joinFamily(familyCode: String) async throws -> JoinFamilyResponse? {
    let data = try await send("POST", "api/family/code/join", body: ["familyCode": familyCode])
    return try? JSONDecoder().decode(JoinFamilyResponse.self, from: data)
  }

  /// POST /api/family/player-details. `familyUnitId` is always sent explicitly: the server default (newest
  /// family joined) is only a convenience for old clients.
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws {
    _ = try await send(
      "POST", "api/family/player-details",
      query: [URLQueryItem(name: "familyUnitId", value: familyId)],
      jsonBody: try JSONEncoder().encode(PlayerDetailsRequest(details))
    )
  }

  private func send(_ method: String, _ path: String, body: [String: String]? = nil) async throws -> Data {
    try await send(method, path, jsonBody: try body.map { try JSONEncoder().encode($0) })
  }

  private func send(
    _ method: String, _ path: String, query: [URLQueryItem] = [], jsonBody: Data? = nil
  ) async throws -> Data {
    guard let baseURL else {
      familyServiceLogger.error("\(path, privacy: .public): API_BASE_URL is not configured")
      throw FamilyError.serverError(Self.notConfiguredMessage)
    }
    var url = baseURL.appendingPathComponent(path)
    if !query.isEmpty {
      // Never fall through without the query: a dropped familyUnitId would silently target the server default.
      guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        throw FamilyError.serverError(Self.genericFailureMessage)
      }
      components.queryItems = query
      guard let withQuery = components.url else { throw FamilyError.serverError(Self.genericFailureMessage) }
      url = withQuery
    }
    var request = URLRequest(url: url)
    request.addClientHeaders()
    request.httpMethod = method
    request.setValue("Bearer \(try await tokenProvider())", forHTTPHeaderField: "Authorization")
    if let jsonBody {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = jsonBody
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      familyServiceLogger.error("\(method) \(path, privacy: .public) network error: \(error.localizedDescription)")
      throw FamilyError.serverError(error.localizedDescription)
    }
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      familyServiceLogger.error("\(method) \(path, privacy: .public) failed: status=\(status)")
      throw FamilyError.serverError(Self.serverMessage(in: data) ?? Self.genericFailureMessage)
    }
    return data
  }

  /// h3 error bodies carry `message` (and `statusMessage`); anything else is not safe to show.
  private static func serverMessage(in data: Data) -> String? {
    struct ErrorBody: Decodable {
      let message: String?
      let statusMessage: String?
    }
    guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else { return nil }
    let text = (body.message ?? body.statusMessage)?.trimmingCharacters(in: .whitespacesAndNewlines)
    return text?.isEmpty == false ? text : nil
  }
}

/// Wire shape of POST /api/family/player-details (server/api/family/player-details.post.ts): one combined
/// `playerName`, camelCase keys, absent optionals omitted. Distinct from PendingPlayerDetails, whose
/// first_name/last_name shape is still what the invite route and the legacy direct write use.
private struct PlayerDetailsRequest: Encodable {
  let playerName: String
  let playerDob: String?
  let graduationYear: Int?
  let sport: String?
  let position: String?

  init(_ details: PendingPlayerDetails) {
    playerName = [details.firstName, details.lastName]
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    playerDob = details.playerDob
    graduationYear = details.graduationYear
    sport = details.sport
    position = details.position
  }
}
