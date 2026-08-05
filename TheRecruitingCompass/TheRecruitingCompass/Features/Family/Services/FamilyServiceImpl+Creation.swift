import Foundation
import Supabase
import OSLog

// MARK: - Family Management (Player + Parent)

extension FamilyServiceImpl {
  /// Creates a family unit for the current user. Idempotent.
  /// Uses the web API when API_BASE_URL is configured (bypasses RLS — required for parent role).
  /// Falls back to direct Supabase inserts when no web API is available (player RLS typically allows this).
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse {
    if let baseURL = SupabaseConfig.apiBaseURL {
      return try await createFamilyViaAPI(baseURL: baseURL)
    }
    return try await createFamilyViaDirect(role: role)
  }

  fileprivate func createFamilyViaAPI(baseURL: URL) async throws -> CreateFamilyResponse {
    let url = baseURL.appendingPathComponent("api/family/create")
    let token = try await supabaseManager.client.auth.session.accessToken
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = Data("{}".utf8)
    familyServiceLogger.info("createFamily: POST \(url.absoluteString, privacy: .public)")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      familyServiceLogger.error("createFamily network error: \(error.localizedDescription, privacy: .public)")
      throw FamilyError.serverError("Failed to create family: \(error.localizedDescription)")
    }

    guard let http = response as? HTTPURLResponse else {
      familyServiceLogger.error("createFamily: response was not HTTPURLResponse")
      throw FamilyError.serverError("Failed to create family")
    }

    guard (200..<300).contains(http.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
      familyServiceLogger.error("createFamily failed: status=\(http.statusCode), body=\(body, privacy: .private)")
      throw FamilyError.serverError("Failed to create family")
    }

    let decoded = try JSONDecoder().decode(CreateFamilyResponse.self, from: data)
    familyServiceLogger.info("createFamily success: status=\(http.statusCode), familyId=\(decoded.familyId, privacy: .private)")
    return decoded
  }

  fileprivate func createFamilyViaDirect(role: UserRole) async throws -> CreateFamilyResponse {
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
    let now = ISO8601DateFormatter().string(from: .now)
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

    familyServiceLogger.info("createFamily via Supabase: familyId=\(familyId), role=\(role.rawValue)")
    return CreateFamilyResponse(
      success: true,
      familyCode: familyCode,
      familyId: familyId,
      familyName: nil
    )
  }

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    familyServiceLogger.debug("Regenerating family code for: \(familyId, privacy: .private)")
    struct RegenerateBody: Encodable {
      let familyId: String
    }
    do {
      let response: RegenerateFamilyCodeResponse = try await supabaseManager.client.functions
        .invoke("family-code-regenerate", options: FunctionInvokeOptions(body: RegenerateBody(familyId: familyId)))
      familyServiceLogger.info("Family code regenerated for: \(familyId, privacy: .private)")
      return response
    } catch {
      familyServiceLogger.error("regenerateCode failed: \(error.localizedDescription)")
      throw error
    }
  }

  func removeFamilyMember(memberId: String) async throws {
    familyServiceLogger.debug("Removing family member: \(memberId, privacy: .private)")
    struct RemoveResponse: Codable {
      let success: Bool
    }
    do {
      let _: RemoveResponse = try await supabaseManager.client.functions
        .invoke("family-members-remove/\(memberId)", options: FunctionInvokeOptions(method: .delete))
      familyServiceLogger.info("Family member removed: \(memberId, privacy: .private)")
    } catch {
      familyServiceLogger.error("removeFamilyMember failed: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Family Management (Parent)

  func joinFamilyWithCode(familyCode: String) async throws {
    familyServiceLogger.debug("Joining family with code")
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
        familyServiceLogger.error("joinFamilyWithCode failed via API")
        throw FamilyError.serverError("Failed to join family")
      }
      familyServiceLogger.info("Joined family via API")
    } else {
      struct JoinBody: Encodable { let familyCode: String }
      struct JoinResponse: Codable { let message: String }
      do {
        let _: JoinResponse = try await supabaseManager.client.functions
          .invoke("family-code-join", options: FunctionInvokeOptions(body: JoinBody(familyCode: familyCode)))
        familyServiceLogger.info("Joined family via Edge Function")
      } catch {
        familyServiceLogger.error("joinFamilyWithCode via Edge Function failed: \(error.localizedDescription)")
        throw error
      }
    }
  }
}
