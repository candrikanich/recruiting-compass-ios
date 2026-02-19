import Foundation
import Observation

@Observable
@MainActor
final class PrivacyPolicyViewModel {
  var lastUpdated: String = ""
  var isLoading = false

  func loadPolicy() async {
    isLoading = true
    defer { isLoading = false }

    lastUpdated = PrivacyPolicy.bundled.formattedDate
  }
}
