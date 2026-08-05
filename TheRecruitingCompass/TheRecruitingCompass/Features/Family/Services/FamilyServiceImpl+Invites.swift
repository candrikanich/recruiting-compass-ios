import Foundation
import Supabase
import OSLog

// MARK: - Invite Methods

extension FamilyServiceImpl {
  func sendEmailInvite(email: String, role: String, pendingPlayerDetails: PendingPlayerDetails? = nil) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      familyServiceLogger.error("sendEmailInvite: API_BASE_URL not configured")
      throw FamilyError.serverError("API base URL not configured. Set API_BASE_URL for invite features.")
    }
    let inviteURL = baseURL.appendingPathComponent("api/family/invite")
    familyServiceLogger.info("sendEmailInvite: POST \(inviteURL.absoluteString, privacy: .public) email=\(email.prefix(3))*** role=\(role)")

    let token = try await supabaseManager.client.auth.session.accessToken

    struct Body: Encodable {
      let email: String
      let role: String
      let pendingPlayerDetails: PendingPlayerDetails?

      enum CodingKeys: String, CodingKey {
        case email
        case role
        case pendingPlayerDetails = "pending_player_details"
      }
    }

    var request = URLRequest(url: baseURL.appendingPathComponent("api/family/invite"))
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(Body(email: email, role: role, pendingPlayerDetails: pendingPlayerDetails))

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      familyServiceLogger.error("sendEmailInvite network error: \(error.localizedDescription, privacy: .public)")
      throw FamilyError.serverError("Failed to send invite: \(error.localizedDescription)")
    }

    guard let http = response as? HTTPURLResponse else {
      familyServiceLogger.error("sendEmailInvite: response was not HTTPURLResponse")
      throw FamilyError.serverError("Failed to send invite")
    }

    guard (200..<300).contains(http.statusCode) else {
      let bodyString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
      familyServiceLogger.error("sendEmailInvite failed: status=\(http.statusCode), body=\(bodyString, privacy: .private)")
      throw FamilyError.serverError("Failed to send invite")
    }

    familyServiceLogger.info("sendEmailInvite success: status=\(http.statusCode)")
  }

  func fetchPendingInvitations() async throws -> [FamilyInvitation] {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      familyServiceLogger.debug("fetchPendingInvitations: API_BASE_URL not configured, returning empty")
      return []
    }
    familyServiceLogger.debug("Fetching pending invitations")
    let token = try await supabaseManager.client.auth.session.accessToken

    var request = URLRequest(url: baseURL.appendingPathComponent("api/family/invitations"))
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      familyServiceLogger.warning("fetchPendingInvitations returned non-200, treating as empty")
      return []
    }

    struct InvitationsResponse: Codable {
      let invitations: [FamilyInvitation]
    }
    do {
      let decoded = try JSONDecoder().decode(InvitationsResponse.self, from: data)
      familyServiceLogger.info("Fetched \(decoded.invitations.count) pending invitations")
      return decoded.invitations
    } catch {
      let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "(unable to decode)"
      familyServiceLogger.error("fetchPendingInvitations decode failed: \(error.localizedDescription, privacy: .public), body=\(bodyPreview, privacy: .private)")
      throw error
    }
  }

  func revokeInvitation(id: String) async throws {
    familyServiceLogger.debug("Revoking invitation: \(id, privacy: .private)")
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      throw FamilyError.serverError("API base URL not configured")
    }
    let token = try await supabaseManager.client.auth.session.accessToken

    let safeId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
    var request = URLRequest(
      url: baseURL
        .appendingPathComponent("api/family/invitations")
        .appendingPathComponent(safeId)
    )
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      familyServiceLogger.error("revokeInvitation failed for: \(id, privacy: .private)")
      throw FamilyError.serverError("Failed to revoke invite")
    }
    familyServiceLogger.info("Invitation revoked: \(id, privacy: .private)")
  }

  func lookupInviteByToken(_ token: String) async throws -> InviteDetails {
    familyServiceLogger.debug("Looking up invite by token")
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      throw FamilyError.serverError("API base URL not configured")
    }

    let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
    let url = baseURL
      .appendingPathComponent("api/family/invite")
      .appendingPathComponent(safeToken)
    let (data, response) = try await URLSession.shared.data(from: url)

    guard let http = response as? HTTPURLResponse else {
      throw FamilyError.serverError("Invalid response")
    }
    switch http.statusCode {
    case 200:
      let details = try JSONDecoder().decode(InviteDetails.self, from: data)
      familyServiceLogger.info("Invite lookup succeeded: status=200")
      return details
    case 404:
      familyServiceLogger.info("Invite not found")
      throw InviteError.notFound
    case 409:
      familyServiceLogger.info("Invite already accepted")
      throw InviteError.alreadyAccepted
    case 410:
      familyServiceLogger.info("Invite expired")
      throw InviteError.expired
    default:
      familyServiceLogger.error("lookupInviteByToken unexpected status: \(http.statusCode)")
      throw FamilyError.serverError("Unexpected status \(http.statusCode)")
    }
  }

  func acceptInvite(token: String) async throws {
    familyServiceLogger.debug("Accepting invite")
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      throw FamilyError.serverError("API base URL not configured")
    }
    let accessToken = try await supabaseManager.client.auth.session.accessToken

    let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
    var request = URLRequest(
      url: baseURL
        .appendingPathComponent("api/family/invite")
        .appendingPathComponent(safeToken)
        .appendingPathComponent("accept")
    )
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data("{}".utf8)

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      familyServiceLogger.error("acceptInvite failed: status=\((response as? HTTPURLResponse)?.statusCode ?? -1)")
      throw FamilyError.serverError("Failed to accept invite")
    }
    familyServiceLogger.info("Invite accepted: status=\(http.statusCode)")
  }

  // Decline does NOT require authentication (spec: public endpoint)
  func declineInvite(token: String) async throws {
    familyServiceLogger.debug("Declining invite")
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      throw FamilyError.serverError("API base URL not configured")
    }

    let safeToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
    var request = URLRequest(
      url: baseURL
        .appendingPathComponent("api/family/invite")
        .appendingPathComponent(safeToken)
        .appendingPathComponent("decline")
    )
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data("{}".utf8)

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      familyServiceLogger.error("declineInvite failed: status=\((response as? HTTPURLResponse)?.statusCode ?? -1)")
      throw FamilyError.serverError("Failed to decline invite")
    }
    familyServiceLogger.info("Invite declined: status=\(http.statusCode)")
  }

  func resendInvitation(id: String, email: String, role: String) async throws {
    familyServiceLogger.debug("Resending invitation to: \(email.prefix(3))***")
    try await revokeInvitation(id: id)
    // Brief delay so server can commit revoke before create (avoids soft-delete/race)
    try await Task.sleep(for: .milliseconds(500))
    try await sendEmailInvite(email: email, role: role, pendingPlayerDetails: nil)
    familyServiceLogger.info("Invitation resent to: \(email.prefix(3))***")
  }
}
