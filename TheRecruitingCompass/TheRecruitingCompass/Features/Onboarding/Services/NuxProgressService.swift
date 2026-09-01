import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "NuxProgressService")

protocol NuxProgressManaging: Sendable {
  func fetchNuxProgress(userId: String) async throws -> NuxProgress
  func saveNuxProgress(userId: String, progress: NuxProgress) async throws
}

/// Sendable: Stateless service with no mutable properties
final class NuxProgressServiceImpl: NuxProgressManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager) {
    self.supabaseManager = supabaseManager
  }

  func fetchNuxProgress(userId: String) async throws -> NuxProgress {
    logger.debug("Fetching nux_progress for user: \(userId, privacy: .private)")

    struct NuxRow: Decodable {
      let nuxProgress: NuxProgress?

      enum CodingKeys: String, CodingKey {
        case nuxProgress = "nux_progress"
      }
    }

    let rows: [NuxRow] = try await supabaseManager.client
      .from("users")
      .select("nux_progress")
      .eq("id", value: userId)
      .limit(1)
      .execute()
      .value

    guard let row = rows.first, let progress = row.nuxProgress else {
      logger.debug("No nux_progress found for user \(userId, privacy: .private), returning empty")
      return .empty
    }

    logger.info("Fetched nux_progress for user \(userId, privacy: .private) (v\(progress.version))")
    return progress
  }

  func saveNuxProgress(userId: String, progress: NuxProgress) async throws {
    guard let baseURL = SupabaseConfig.apiBaseURL else {
      logger.warning("API_BASE_URL not configured, skipping nux_progress save")
      return
    }

    guard let session = try? await supabaseManager.client.auth.session else {
      logger.warning("No auth session, skipping nux_progress save")
      return
    }

    let url = baseURL.appendingPathComponent("api/user/nux-progress")
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let payload = try encoder.encode(["nux_progress": progress])
    request.httpBody = payload

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let http = response as? HTTPURLResponse else {
      logger.error("nux_progress save: invalid response")
      throw NuxProgressAPIError.invalidResponse
    }

    guard http.statusCode == 200 else {
      logger.error("nux_progress save failed: HTTP \(http.statusCode)")
      throw NuxProgressAPIError.serverError(http.statusCode)
    }

    logger.info("Saved nux_progress for user \(userId, privacy: .private)")
  }
}

enum NuxProgressAPIError: LocalizedError {
  case invalidResponse
  case serverError(Int)

  var errorDescription: String? {
    switch self {
    case .invalidResponse: return "Couldn't reach the server."
    case .serverError(let code): return "Server error (\(code)). Please try again."
    }
  }
}
