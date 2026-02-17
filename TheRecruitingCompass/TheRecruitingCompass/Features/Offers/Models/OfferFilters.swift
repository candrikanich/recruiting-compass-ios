import Foundation

struct OfferFilters: Sendable {
  var schoolSearch: String = ""
  var status: OfferStatus?
  var offerType: OfferType?
  var sortBy: OfferSortField = .offerDate
  var sortDirection: SortDirection = .descending

  var hasActiveFilters: Bool {
    !schoolSearch.isEmpty || status != nil || offerType != nil
  }

  var activeFilterCount: Int {
    [
      !schoolSearch.isEmpty,
      status != nil,
      offerType != nil
    ].filter(\.self).count
  }
}

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

enum SortDirection: String, CaseIterable, Sendable {
  case ascending
  case descending

  var displayName: String {
    switch self {
    case .ascending: return "Ascending"
    case .descending: return "Descending"
    }
  }
}
