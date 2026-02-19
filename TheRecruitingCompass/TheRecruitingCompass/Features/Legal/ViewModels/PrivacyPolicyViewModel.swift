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
      lastUpdated = try LegalDocumentLoader.loadLastUpdated(formattedDate: PrivacyPolicy.bundled.formattedDate)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func retry() async {
    errorMessage = nil
    await load()
  }
}
