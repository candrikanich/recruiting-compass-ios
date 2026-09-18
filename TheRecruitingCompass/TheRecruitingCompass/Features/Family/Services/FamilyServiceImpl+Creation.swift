import Foundation
import Supabase
import OSLog

// MARK: - Family Management (Player + Parent)

extension FamilyServiceImpl {
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
