import Foundation
import Observation

@Observable
@MainActor
final class PrivacyPolicyViewModel: LegalDocumentLoading {
  var lastUpdated: String = ""
  var isLoading = false
  var errorMessage: String?

  nonisolated deinit {}

  func load() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      lastUpdated = try Self.loadBundledLastUpdated()
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  /// Loads the bundled policy's "last updated" string. Throws if the formatted date is empty (e.g. locale/formatting edge case).
  private static func loadBundledLastUpdated() throws -> String {
    let formatted = PrivacyPolicy.bundled.formattedDate
    guard !formatted.isEmpty else {
      throw NSError(domain: "PrivacyPolicyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load policy date."])
    }
    return formatted
  }

  func retry() async {
    errorMessage = nil
    await load()
  }
}
