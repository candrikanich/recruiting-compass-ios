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

  func joinFamily(familyCode: String) async throws {
    _ = try await send("POST", "api/family/code/join", body: ["familyCode": familyCode])
  }

  enum PlayerDetailsOutcome: Equatable, Sendable {
    case saved
    /// 404 from a server that predates POST /api/family/player-details (it reaches prod with the next web
    /// promotion). Lets the caller fall back to the legacy direct write instead of failing onboarding.
    case endpointUnavailable
  }

  /// POST /api/family/player-details. `familyUnitId` is always sent explicitly: the server default (newest
  /// family joined) is only a convenience for old clients.
  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws -> PlayerDetailsOutcome {
    let path = "api/family/player-details"
    let (data, status) = try await perform(
      "POST", path,
      query: [URLQueryItem(name: "familyUnitId", value: familyId)],
      jsonBody: try JSONEncoder().encode(PlayerDetailsRequest(details))
    )
    if status == 404 { return .endpointUnavailable }
    try Self.requireSuccess(status, data: data, method: "POST", path: path)
    return .saved
  }

  private func send(_ method: String, _ path: String, body: [String: String]? = nil) async throws -> Data {
    let (data, status) = try await perform(method, path, jsonBody: try body.map { try JSONEncoder().encode($0) })
    try Self.requireSuccess(status, data: data, method: method, path: path)
    return data
  }

  private static func requireSuccess(_ status: Int, data: Data, method: String, path: String) throws {
    guard (200..<300).contains(status) else {
      familyServiceLogger.error("\(method) \(path, privacy: .public) failed: status=\(status)")
      throw FamilyError.serverError(serverMessage(in: data) ?? genericFailureMessage)
    }
  }

  /// Sends the request and returns the raw status; only transport failures throw.
  private func perform(
    _ method: String, _ path: String, query: [URLQueryItem] = [], jsonBody: Data? = nil
  ) async throws -> (Data, Int) {
    guard let baseURL else {
      familyServiceLogger.error("\(path, privacy: .public): API_BASE_URL is not configured")
      throw FamilyError.serverError(Self.notConfiguredMessage)
    }
    var url = baseURL.appendingPathComponent(path)
    if !query.isEmpty, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
      components.queryItems = query
      url = components.url ?? url
    }
    var request = URLRequest(url: url)
    request.addClientHeaders()
    request.httpMethod = method
    request.setValue("Bearer \(try await tokenProvider())", forHTTPHeaderField: "Authorization")
    if let jsonBody {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = jsonBody
    }

    do {
      let (data, response) = try await session.data(for: request)
      return (data, (response as? HTTPURLResponse)?.statusCode ?? -1)
    } catch {
      familyServiceLogger.error("\(method) \(path, privacy: .public) network error: \(error.localizedDescription)")
      throw FamilyError.serverError(error.localizedDescription)
    }
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
