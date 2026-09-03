import Foundation

struct TermsOfService {
  let lastUpdated: Date

  var formattedDate: String {
    DateFormatter.legalDocument.string(from: lastUpdated)
  }

  static var bundled: TermsOfService {
    TermsOfService(lastUpdated: LegalRevision.termsLastUpdated)
  }
}
