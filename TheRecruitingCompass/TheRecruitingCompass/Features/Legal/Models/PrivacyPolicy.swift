import Foundation

struct PrivacyPolicy {
  let lastUpdated: Date

  var formattedDate: String {
    DateFormatter.legalDocument.string(from: lastUpdated)
  }

  static var bundled: PrivacyPolicy {
    PrivacyPolicy(
      lastUpdated: Date(timeIntervalSince1970: 1739404800) // February 19, 2026
    )
  }
}
