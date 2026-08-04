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
