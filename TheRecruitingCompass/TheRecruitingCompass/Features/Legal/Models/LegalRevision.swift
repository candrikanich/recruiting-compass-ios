import Foundation

/// Single source of truth for the legal documents' "Last Updated" date, shared by both
/// Terms of Service and Privacy Policy. Mirrors the web app's `CURRENT_TERMS_VERSION`
/// (utils/legal.ts) and the "Last Updated" date shown on the web legal pages. Bump all
/// three in lockstep whenever the legal documents materially change.
enum LegalRevision {
  /// August 16, 2026 — current Privacy Policy revision.
  static let lastUpdated: Date = makeDate(year: 2026, month: 8, day: 16)

  /// September 3, 2026 — Terms revision that added §22 Subscriptions and Payments.
  /// Mirrors web `CURRENT_TERMS_VERSION` (utils/legal.ts) and pages/legal/terms.vue "Last Updated". Bump in lockstep.
  static let termsLastUpdated: Date = makeDate(year: 2026, month: 9, day: 3)

  private static func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar(identifier: .gregorian).date(from: components) ?? .now
  }
}
