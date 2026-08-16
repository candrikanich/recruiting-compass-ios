import Foundation

/// Single source of truth for the legal documents' "Last Updated" date, shared by both
/// Terms of Service and Privacy Policy. Mirrors the web app's `CURRENT_TERMS_VERSION`
/// (utils/legal.ts) and the "Last Updated" date shown on the web legal pages. Bump all
/// three in lockstep whenever the legal documents materially change.
enum LegalRevision {
  /// August 16, 2026 — the current published revision.
  static let lastUpdated: Date = {
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 16
    return Calendar(identifier: .gregorian).date(from: components) ?? .now
  }()
}
