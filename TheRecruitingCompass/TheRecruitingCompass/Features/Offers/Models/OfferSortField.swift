import Foundation

enum OfferSortField: String, CaseIterable, Sendable {
  case offerDate
  case deadline
  case percentage
  case amount

  var displayName: String {
    switch self {
    case .offerDate: return String(localized: "Offer Date")
    case .deadline: return String(localized: "Deadline")
    case .percentage: return String(localized: "Percentage")
    case .amount: return String(localized: "Amount")
    }
  }
}
