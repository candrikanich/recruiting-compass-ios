import Foundation
import Observation

@Observable
@MainActor
final class TermsOfServiceViewModel {
  var lastUpdated: String = ""
  var isLoading = false
  var errorMessage: String?

  func loadTerms() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    lastUpdated = TermsOfService.bundled.formattedDate
  }

  func retry() async {
    errorMessage = nil
    await loadTerms()
  }
}
