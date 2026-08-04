import Foundation

enum OfferSortField: String, CaseIterable, Sendable {
  case offerDate
  case deadline
  case percentage
  case amount

  var displayName: String {
    switch self {
    case .offerDate: return "Offer Date"
    case .deadline: return "Deadline"
    case .percentage: return "Percentage"
    case .amount: return "Amount"
    }
  }
}
