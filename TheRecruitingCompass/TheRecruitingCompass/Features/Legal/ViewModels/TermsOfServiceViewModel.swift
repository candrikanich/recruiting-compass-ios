import Foundation
import Observation

@Observable
@MainActor
final class TermsOfServiceViewModel {
  /// Last updated date string from bundled Terms of Service (synchronous; no loading).
  var lastUpdated: String { TermsOfService.bundled.formattedDate }


}
