import Foundation

enum LegalDocumentLoader {
  /// Returns the formatted "last updated" string from a bundled legal document.
  /// Throws if the string is empty (e.g. locale/formatting edge case).
  static func loadLastUpdated(formattedDate: String) throws -> String {
    guard !formattedDate.isEmpty else {
      throw NSError(
        domain: "LegalDocumentLoader",
        code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to load document date."]
      )
    }
    return formattedDate
  }
}
