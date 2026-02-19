import Foundation
import Observation

@Observable
@MainActor
final class TermsOfServiceViewModel {
  var lastUpdated: String = ""
  var isLoading = false

  func loadTerms() async {
    isLoading = true
    defer { isLoading = false }

    lastUpdated = TermsOfService.bundled.formattedDate
  }
}
