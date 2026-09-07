import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ScholarshipLimitsService"
)

protocol ScholarshipLimitsServicing: Sendable {
  func fetchLimits() async throws -> [ScholarshipLimit]
}

/// Loads the global `scholarship_limits` config once per session; fails OPEN
/// (returns []) on ANY error — an empty/unseeded table must never break the
/// school detail screen, just hide the scholarship line (matches web
/// composables/useScholarshipLimits.ts and ContactWindowServiceImpl).
actor ScholarshipLimitsServiceImpl: ScholarshipLimitsServicing {
  private let fetch: @Sendable () async throws -> [ScholarshipLimit]
  private var cached: [ScholarshipLimit]?

  /// Production init: query `scholarship_limits` (global reference config).
  init(supabaseManager: SupabaseManager = .shared) {
    self.fetch = {
      try await supabaseManager.client
        .from("scholarship_limits")
        .select("sport, division, total, head_count, equivalency, notes")
        .execute()
        .value
    }
  }

  /// Test seam.
  init(fetch: @escaping @Sendable () async throws -> [ScholarshipLimit]) {
    self.fetch = fetch
  }

  func fetchLimits() async throws -> [ScholarshipLimit] {
    if let cached { return cached }
    do {
      let rows = try await fetch()
      cached = rows
      logger.info("Loaded \(rows.count) scholarship limits")
      return rows
    } catch {
      logger.warning("fetchLimits failed; returning [] (fail-open): \(error.localizedDescription)")
      cached = []
      return []
    }
  }
}
