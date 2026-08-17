import SwiftUI

struct OfferEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddOffer: (() -> Void)?

  private var icon: String {
    isFilteredEmpty ? "magnifyingglass" : "doc.text.fill"
  }

  private var title: String {
    isFilteredEmpty ? String(localized: "No Matching Offers") : String(localized: "No Offers Yet")
  }

  private var message: String {
    isFilteredEmpty
      ? String(localized: "Try adjusting your search or filters")
      : String(localized: "Start logging your scholarship offers to track your recruiting journey")
  }

  private var actionTitle: String? {
    if isFilteredEmpty { return onClearFilters != nil ? String(localized: "Clear Filters") : nil }
    return onAddOffer != nil ? String(localized: "Log Your First Offer") : nil
  }

  private var actionHint: String? {
    isFilteredEmpty
      ? String(localized: "Removes all active filters and search text")
      : String(localized: "Opens the form to log an offer")
  }

  private var action: (() -> Void)? {
    isFilteredEmpty ? onClearFilters : onAddOffer
  }

  var body: some View {
    EmptyStateView(
      icon: icon,
      title: title,
      message: message,
      actionTitle: actionTitle,
      actionHint: actionHint,
      action: action
    )
  }
}

#Preview("No Data") {
  OfferEmptyState(isFilteredEmpty: false, onClearFilters: nil, onAddOffer: {})
}

#Preview("Filtered Empty") {
  OfferEmptyState(isFilteredEmpty: true, onClearFilters: {})
}
