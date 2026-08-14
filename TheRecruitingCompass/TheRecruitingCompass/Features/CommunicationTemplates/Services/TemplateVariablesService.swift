import Foundation
import OSLog
import Supabase

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "TemplateVariablesService"
)

protocol TemplateVariablesServicing: Sendable {
  func fetchRegistry() async throws -> [TemplateVariableDef]
}

actor TemplateVariablesServiceImpl: TemplateVariablesServicing {
  private let fetch: @Sendable () async throws -> [TemplateVariableDef]
  private var cached: [TemplateVariableDef]?

  /// Production init: query `template_variables` (global, ordered by sort_order).
  init(supabaseManager: SupabaseManager = .shared) {
    self.fetch = {
      try await supabaseManager.client
        .from("template_variables")
        .select()
        .order("sort_order", ascending: true)
        .execute()
        .value
    }
  }

  /// Test seam.
  init(fetch: @escaping @Sendable () async throws -> [TemplateVariableDef]) {
    self.fetch = fetch
  }

  func fetchRegistry() async throws -> [TemplateVariableDef] {
    if let cached { return cached }
    do {
      let rows = try await fetch()
      cached = rows
      logger.info("Loaded \(rows.count) template variable defs")
      return rows
    } catch {
      if isMissingTableError(error) {
        logger.warning("template_variables table absent; returning [] (fail-open)")
        cached = []
        return []
      }
      logger.error("fetchRegistry failed: \(error.localizedDescription)")
      throw error
    }
  }
}
