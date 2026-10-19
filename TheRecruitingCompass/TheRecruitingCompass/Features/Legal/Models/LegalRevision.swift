import Foundation

/// Single source of truth for the legal documents' "Last Updated" date, shared by both
/// Terms of Service and Privacy Policy. Mirrors the web app's `CURRENT_TERMS_VERSION`
/// (utils/legal.ts) and the "Last Updated" date shown on the web legal pages. Bump all
/// three in lockstep whenever the legal documents materially change.
enum LegalRevision {
  /// October 2, 2026 — current Privacy Policy revision.
  static let lastUpdated: Date = makeDate(year: 2026, month: 10, day: 2)

  /// October 19, 2026 — Terms revision that removed website-billing language from §22 (restore with web billing, web#617).
  /// Mirrors web `CURRENT_TERMS_VERSION` (utils/legal.ts) and pages/legal/terms.vue "Last Updated". Bump in lockstep.
  static let termsLastUpdated: Date = makeDate(year: 2026, month: 10, day: 19)

  private static func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar(identifier: .gregorian).date(from: components) ?? .now
  }
}
