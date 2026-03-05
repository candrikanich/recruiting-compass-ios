import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FamilyService")

/// Sendable: Stateless service with no mutable properties
final class FamilyServiceImpl: FamilyManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  // MARK: - Existing Methods

  func fetchFamilyMembers(familyUnitId: String) async throws -> [FamilyMember] {
    logger.debug("Fetching family members for family unit: \(familyUnitId)")

    // IMPORTANT: Fetch family_members and users separately to avoid join issues
    // RLS policies allow users to see all members in their families
    struct FamilyMemberRow: Codable {
      let id: String
      let userId: String
      let familyUnitId: String
      let role: String
      let addedAt: String?

      enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case role
        case addedAt = "added_at"
      }
    }

    // Step 1: Fetch family_members (RLS allows seeing all members in your family)
    let memberRows: [FamilyMemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("id, user_id, family_unit_id, role, added_at")
      .eq("family_unit_id", value: familyUnitId)
      .order("added_at")
      .execute()
      .value

    logger.debug("Fetched \(memberRows.count) family member rows")

    guard !memberRows.isEmpty else {
      return []
    }

    // Step 2: Fetch user details (RLS allows seeing profiles of family members)
    let userIds = memberRows.map { $0.userId }
    logger.debug("Fetching user details for \(userIds.count) user IDs")

    let users: [FamilyMemberUser] = try await supabaseManager.client
      .from("users")
      .select("id, email, full_name, role")
      .in("id", values: userIds)
      .execute()
      .value

    logger.debug("Fetched \(users.count) user records")

    // Step 3: Combine family_members with user data
    let usersMap = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })

    let members = memberRows.map { row in
      FamilyMember(
        id: row.id,
        userId: row.userId,
        familyUnitId: row.familyUnitId,
        role: row.role,
        addedAt: row.addedAt,
        user: usersMap[row.userId]
      )
    }

    logger.debug("Returning \(members.count) family members with user details")
    for member in members {
      logger.debug("Member: id=\(member.id, privacy: .private), role=\(member.role), userId=\(member.userId, privacy: .private), userName=\(member.user?.fullName ?? "nil", privacy: .private)")
    }

    return members
  }

  func getCurrentMember(userId: String) async throws -> FamilyMember? {
    // Fetch family_member record
    struct FamilyMemberRow: Codable {
      let id: String
      let userId: String
      let familyUnitId: String
      let role: String
      let addedAt: String?

      enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case role
        case addedAt = "added_at"
      }
    }

    let memberRows: [FamilyMemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("id, user_id, family_unit_id, role, added_at")
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = memberRows.first else {
      return nil
    }

    // Fetch user details
    let users: [FamilyMemberUser] = try await supabaseManager.client
      .from("users")
      .select("id, email, full_name, role")
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    return FamilyMember(
      id: row.id,
      userId: row.userId,
      familyUnitId: row.familyUnitId,
      role: row.role,
      addedAt: row.addedAt,
      user: users.first
    )
  }

  func getFamilyUnit(forUserId userId: String) async throws -> FamilyUnit? {
    struct MemberRow: Codable {
      let familyUnitId: String
      enum CodingKeys: String, CodingKey {
        case familyUnitId = "family_unit_id"
      }
    }
    let rows: [MemberRow] = try await supabaseManager.client
      .from("family_members")
      .select("family_unit_id")
      .eq("user_id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = rows.first else { return nil }

    let units: [FamilyUnit] = try await supabaseManager.client
      .from("family_units")
      .select()
      .eq("id", value: row.familyUnitId)
      .limit(1)
      .execute()
      .value

    return units.first
  }

  // MARK: - Family Management (Player + Parent)

  /// Creates a family unit for the current user via direct Supabase. Idempotent.
  /// Both players and parents can create families.
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse {
    let userId = try await supabaseManager.client.auth.session.user.id.uuidString

    // Idempotent: return existing family if present
    if let existing = try await getFamilyUnit(forUserId: userId),
       let code = existing.familyCode {
      return CreateFamilyResponse(
        success: true,
        familyCode: code,
        familyId: existing.id,
        familyName: existing.familyName
      )
    }

    let familyId = UUID().uuidString
    let memberId = UUID().uuidString
    let now = ISO8601DateFormatter().string(from: Date())
    let familyCode = "FAM-" + String((0..<6).map { _ in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()! })

    struct FamilyUnitInsert: Encodable {
      let id: String
      let createdByUserId: String
      let familyCode: String
      let codeGeneratedAt: String
      let createdAt: String
      let updatedAt: String

      enum CodingKeys: String, CodingKey {
        case id
        case createdByUserId = "created_by_user_id"
        case familyCode = "family_code"
        case codeGeneratedAt = "code_generated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
      }
    }

    struct FamilyMemberInsert: Encodable {
      let id: String
      let userId: String
      let familyUnitId: String
      let role: String
      let addedAt: String

      enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case familyUnitId = "family_unit_id"
        case role
        case addedAt = "added_at"
      }
    }

    try await supabaseManager.client
      .from("family_units")
      .insert(FamilyUnitInsert(
        id: familyId,
        createdByUserId: userId,
        familyCode: familyCode,
        codeGeneratedAt: now,
        createdAt: now,
        updatedAt: now
      ))
      .execute()

    try await supabaseManager.client
      .from("family_members")
      .insert(FamilyMemberInsert(
        id: memberId,
        userId: userId,
        familyUnitId: familyId,
        role: role.rawValue,
        addedAt: now
      ))
      .execute()

    logger.info("Family created via Supabase: familyId=\(familyId), role=\(role.rawValue)")
    return CreateFamilyResponse(
      success: true,
      familyCode: familyCode,
      familyId: familyId,
      familyName: nil
    )
  }

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    struct RegenerateBody: Encodable {
      let familyId: String
    }
    let response: RegenerateFamilyCodeResponse = try await supabaseManager.client.functions
      .invoke("family-code-regenerate", options: FunctionInvokeOptions(body: RegenerateBody(familyId: familyId)))
    return response
  }

  func removeFamilyMember(memberId: String) async throws {
    struct RemoveResponse: Codable {
      let success: Bool
    }
    let _: RemoveResponse = try await supabaseManager.client.functions
      .invoke("family-members-remove/\(memberId)", options: FunctionInvokeOptions(method: .delete))
  }

  // MARK: - Family Management (Parent)

  func joinFamilyWithCode(familyCode: String) async throws {
    if let baseURL = SupabaseConfig.apiBaseURL {
      let token = try await supabaseManager.client.auth.session.accessToken
      struct Body: Encodable {
        let familyCode: String
        enum CodingKeys: String, CodingKey { case familyCode }
      }
      var request = URLRequest(
        url: baseURL.appendingPathComponent("api/family/code/join")
      )
      request.httpMethod = "POST"
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
      request.httpBody = try JSONEncoder().encode(Body(familyCode: familyCode))

      let (_, response) = try await URLSession.shared.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        throw FamilyError.serverError("Failed to join family")
      }
    } else {
      struct JoinBody: Encodable { let familyCode: String }
      struct JoinResponse: Codable { let message: String }
      let _: JoinResponse = try await supabaseManager.client.functions
        .invoke("family-code-join", options: FunctionInvokeOptions(body: JoinBody(familyCode: familyCode)))
    }
  }

  // MARK: - Invite Methods

  func sendEmailInvite(email: String, role: String, pendingPlayerDetails: PendingPlayerDetails? = nil) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      logger.error("sendEmailInvite: API_BASE_URL not configured")
      throw FamilyError.serverError("API base URL not configured. Set API_BASE_URL for invite features.")
    }
    let inviteURL = baseURL.appendingPathComponent("api/family/invite")
    logger.info("sendEmailInvite: POST \(inviteURL.absoluteString, privacy: .public) email=\(email.prefix(3))*** role=\(role)")

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
      logger.error("sendEmailInvite network error: \(error.localizedDescription, privacy: .public)")
      throw FamilyError.serverError("Failed to send invite: \(error.localizedDescription)")
    }

    guard let http = response as? HTTPURLResponse else {
      logger.error("sendEmailInvite: response was not HTTPURLResponse")
      throw FamilyError.serverError("Failed to send invite")
    }

    guard (200..<300).contains(http.statusCode) else {
      let bodyString = String(data: data, encoding: .utf8) ?? "(unable to decode)"
      logger.error("sendEmailInvite failed: status=\(http.statusCode), body=\(bodyString, privacy: .private)")
      throw FamilyError.serverError("Failed to send invite")
    }

    logger.info("sendEmailInvite success: status=\(http.statusCode)")
  }

  func fetchPendingInvitations() async throws -> [FamilyInvitation] {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      return []
    }
    let token = try await supabaseManager.client.auth.session.accessToken

    var request = URLRequest(url: baseURL.appendingPathComponent("api/family/invitations"))
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      return []
    }

    struct InvitationsResponse: Codable {
      let invitations: [FamilyInvitation]
    }
    do {
      let decoded = try JSONDecoder().decode(InvitationsResponse.self, from: data)
      return decoded.invitations
    } catch {
      let bodyPreview = String(data: data.prefix(500), encoding: .utf8) ?? "(unable to decode)"
      logger.error("fetchPendingInvitations decode failed: \(error.localizedDescription, privacy: .public), body=\(bodyPreview, privacy: .private)")
      throw error
    }
  }

  func revokeInvitation(id: String) async throws {
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
      throw FamilyError.serverError("Failed to revoke invite")
    }
  }

  func lookupInviteByToken(_ token: String) async throws -> InviteDetails {
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
      return try JSONDecoder().decode(InviteDetails.self, from: data)
    case 404:
      throw InviteError.notFound
    case 409:
      throw InviteError.alreadyAccepted
    case 410:
      throw InviteError.expired
    default:
      throw FamilyError.serverError("Unexpected status \(http.statusCode)")
    }
  }

  func acceptInvite(token: String) async throws {
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
      throw FamilyError.serverError("Failed to accept invite")
    }
  }

  // Decline does NOT require authentication (spec: public endpoint)
  func declineInvite(token: String) async throws {
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
      throw FamilyError.serverError("Failed to decline invite")
    }
  }

  func resendInvitation(id: String, email: String, role: String) async throws {
    try await revokeInvitation(id: id)
    // Brief delay so server can commit revoke before create (avoids soft-delete/race)
    try await Task.sleep(nanoseconds: 500_000_000)
    try await sendEmailInvite(email: email, role: role, pendingPlayerDetails: nil)
  }

  func savePlayerDetails(familyId: String, details: PendingPlayerDetails) async throws {
    struct UpdatePayload: Encodable {
      let pendingPlayerDetails: PendingPlayerDetails

      enum CodingKeys: String, CodingKey {
        case pendingPlayerDetails = "pending_player_details"
      }
    }
    try await supabaseManager.client
      .from("family_units")
      .update(UpdatePayload(pendingPlayerDetails: details))
      .eq("id", value: familyId)
      .execute()
  }

  func getParentFamilies() async throws -> [ParentFamilyData] {
    guard let userId = try await supabaseManager.client.auth.session.user.id.uuidString as String? else {
      throw FamilyError.notAuthenticated
    }

    let memberships: [ParentFamilyMembership] = try await supabaseManager.client
      .from("family_members")
      .select("family_unit_id, family_units!inner(id, family_code, family_name, code_generated_at)")
      .eq("user_id", value: userId)
      .eq("role", value: "parent")
      .execute()
      .value

    return memberships.map { membership in
      let fu = membership.familyUnit
      return ParentFamilyData(
        familyId: fu.id,
        familyCode: fu.familyCode ?? "",
        familyName: fu.familyName ?? "My Family",
        codeGeneratedAt: fu.codeGeneratedAt ?? ""
      )
    }
  }
}

// MARK: - Internal Types

private struct ParentFamilyMembership: Codable {
  let familyUnitId: String
  let familyUnit: FamilyUnitData

  enum CodingKeys: String, CodingKey {
    case familyUnitId = "family_unit_id"
    case familyUnit = "family_units"
  }

  struct FamilyUnitData: Codable {
    let id: String
    let familyCode: String?
    let familyName: String?
    let codeGeneratedAt: String?

    enum CodingKeys: String, CodingKey {
      case id
      case familyCode = "family_code"
      case familyName = "family_name"
      case codeGeneratedAt = "code_generated_at"
    }
  }
}
