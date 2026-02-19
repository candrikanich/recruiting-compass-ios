import Foundation

extension DateFormatter {

  /// Shared formatter for "Last updated" dates in legal documents (Privacy Policy, Terms of Service).
  /// Uses long date style for consistent, locale-aware display.
  static let legalDocument: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    return formatter
  }()
}
