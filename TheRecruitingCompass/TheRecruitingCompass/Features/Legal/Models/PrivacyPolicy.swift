import Foundation

struct PrivacyPolicy {
  let lastUpdated: Date

  var formattedDate: String {
    DateFormatter.legalDocument.string(from: lastUpdated)
  }

  static var bundled: PrivacyPolicy {
    PrivacyPolicy(lastUpdated: LegalRevision.lastUpdated)
  }
}
