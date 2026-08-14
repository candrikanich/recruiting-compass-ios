import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "ContactWindowService"
)

protocol ContactWindowServicing: Sendable {
  func fetchRules() async throws -> [ContactWindowRule]
}

/// Loads the global `contact_window_rules` config once per session; fails OPEN (returns [])
/// on ANY error so a config gap never gates outreach (matches web `useContactWindow.loadRules`).
actor ContactWindowServiceImpl: ContactWindowServicing {
  private let fetch: @Sendable () async throws -> [ContactWindowRule]
  private var cached: [ContactWindowRule]?

  /// Production init: query `contact_window_rules` (global reference config).
  init(supabaseManager: SupabaseManager = .shared) {
    self.fetch = {
      try await supabaseManager.client
        .from("contact_window_rules")
        .select("sport, division, rule_kind, reference, window_date, notes")
        .execute()
        .value
    }
  }

  /// Test seam.
  init(fetch: @escaping @Sendable () async throws -> [ContactWindowRule]) {
    self.fetch = fetch
  }

  func fetchRules() async throws -> [ContactWindowRule] {
    if let cached { return cached }
    do {
      let rows = try await fetch()
      cached = rows
      logger.info("Loaded \(rows.count) contact-window rules")
      return rows
    } catch {
      logger.warning("fetchRules failed; returning [] (fail-open): \(error.localizedDescription)")
      cached = []
      return []
    }
  }
}
