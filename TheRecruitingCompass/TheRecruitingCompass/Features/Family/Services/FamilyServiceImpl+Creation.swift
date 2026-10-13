import Foundation
import Supabase
import OSLog

// MARK: - Family Management (Player + Parent)

extension FamilyServiceImpl {
  var apiClient: FamilyAPIClient { .live(supabaseManager) }

  /// Creates a family unit for the current user. Idempotent. Always routes through the
  /// web API (server/api/family/create.post.ts) — the only path that gets the server's
  /// race-hardening (idx_family_units_one_per_creator recovery, idx_player_one_family
  /// disambiguation). A direct-Supabase-writes fallback used to exist for when
  /// API_BASE_URL wasn't configured; it duplicated that hardening in Swift and could
  /// drift out of sync with it, so it was removed (see planning/iOS_SPEC_web-ios-
  /// parity-pass-2026-09-17.md Item 4, web repo) — API_BASE_URL is required on every
  /// iOS build configuration now (it already has a production fallback for Release;
  /// only a misconfigured DEBUG build can hit this).
  func createFamily(role: UserRole) async throws -> CreateFamilyResponse {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      familyServiceLogger.error("createFamily: API_BASE_URL is not configured")
      throw FamilyError.serverError(
        "App is not configured correctly. Please contact support.")
    }
    return try await createFamilyViaAPI(baseURL: baseURL)
  }

  fileprivate func createFamilyViaAPI(baseURL: URL) async throws -> CreateFamilyResponse {
    let url = baseURL.appendingPathComponent("api/family/create")
    let token = try await supabaseManager.client.auth.session.accessToken
    var request = URLRequest(url: url)
    request.addClientHeaders()
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

  func regenerateCode(familyId: String) async throws -> RegenerateFamilyCodeResponse {
    familyServiceLogger.debug("Regenerating family code for: \(familyId, privacy: .private)")
    let response = try await apiClient.regenerateCode(familyId: familyId)
    familyServiceLogger.info("Family code regenerated for: \(familyId, privacy: .private)")
    return response
  }

  func removeFamilyMember(memberId: String) async throws {
    familyServiceLogger.debug("Removing family member: \(memberId, privacy: .private)")
    try await apiClient.removeMember(memberId: memberId)
    familyServiceLogger.info("Family member removed: \(memberId, privacy: .private)")
  }

  // MARK: - Family Management (Parent)

  func joinFamilyWithCode(familyCode: String) async throws {
    familyServiceLogger.debug("Joining family with code")
    try await apiClient.joinFamily(familyCode: familyCode)
    familyServiceLogger.info("Joined family via API")
  }
}
