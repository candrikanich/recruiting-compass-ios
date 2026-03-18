import Foundation
import Observation

@Observable
@MainActor
final class PrivacyPolicyViewModel {

  nonisolated deinit {}
  /// Last updated date string from bundled Privacy Policy (synchronous; no loading).
  var lastUpdated: String { PrivacyPolicy.bundled.formattedDate }


}
