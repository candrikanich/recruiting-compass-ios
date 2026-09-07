import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ScholarshipLimitsLoader"
)

/// Loads NCAA scholarship-limit config, mirroring web's `useScholarshipLimits`.
/// Fails open everywhere (missing table, load error, empty table) — an
/// unseeded `scholarship_limits` table must never break school detail, just
/// hide the scholarship line. Cached in-memory for the life of the app session,
/// same spirit as web's module-scoped cache.
actor ScholarshipLimitsLoader {
  static let shared = ScholarshipLimitsLoader()

  private var cache: [ScholarshipLimit]?

  private init() {}

  func loadLimits(force: Bool = false) async -> [ScholarshipLimit] {
    if let cache, !force { return cache }
    do {
      let limits: [ScholarshipLimit] = try await SupabaseManager.shared.client
        .from("scholarship_limits")
        .select("sport, division, total, head_count, equivalency, notes")
        .execute()
        .value
      cache = limits
      return limits
    } catch {
      logger.error("Load scholarship-limits error: \(error.localizedDescription)")
      return cache ?? []
    }
  }
}
