import SwiftUI

struct OfferEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddOffer: (() -> Void)?

  var body: some View {
    ListEmptyState(
      isFilteredEmpty: isFilteredEmpty,
      filtered: .init(
        icon: "magnifyingglass",
        title: String(localized: "No Matching Offers"),
        message: String(localized: "Try adjusting your search or filters"),
        actionTitle: onClearFilters != nil ? String(localized: "Clear Filters") : nil,
        actionHint: String(localized: "Removes all active filters and search text"),
        action: onClearFilters
      ),
      empty: .init(
        icon: "doc.text.fill",
        title: String(localized: "No Offers Yet"),
        message: String(localized: "Start logging your scholarship offers to track your recruiting journey"),
        actionTitle: onAddOffer != nil ? String(localized: "Log Your First Offer") : nil,
        actionHint: String(localized: "Opens the form to log an offer"),
        action: onAddOffer
      )
    )
  }
}

#Preview("No Data") {
  OfferEmptyState(isFilteredEmpty: false, onClearFilters: nil, onAddOffer: {})
}

#Preview("Filtered Empty") {
  OfferEmptyState(isFilteredEmpty: true, onClearFilters: {})
}
