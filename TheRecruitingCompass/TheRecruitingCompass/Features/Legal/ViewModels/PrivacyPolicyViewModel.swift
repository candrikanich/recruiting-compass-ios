import Foundation
import Observation

@Observable
@MainActor
final class PrivacyPolicyViewModel {
  var lastUpdated: String = ""
  var isLoading = false
  var errorMessage: String?

  func loadPolicy() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    lastUpdated = PrivacyPolicy.bundled.formattedDate
  }

  func retry() async {
    errorMessage = nil
    await loadPolicy()
  }
}
