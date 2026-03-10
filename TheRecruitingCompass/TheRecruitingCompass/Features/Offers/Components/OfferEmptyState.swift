import SwiftUI

struct OfferEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddOffer: (() -> Void)?

  var body: some View {
    if isFilteredEmpty {
      ContentUnavailableView {
        Label("No Matching Offers", systemImage: "magnifyingglass")
      } description: {
        Text("Try adjusting your search or filters")
      } actions: {
        if let onClearFilters {
          Button("Clear Filters", action: onClearFilters)
        }
      }
    } else {
      ContentUnavailableView {
        Label("No Offers Yet", systemImage: "doc.text.fill")
      } description: {
        Text("Start logging your scholarship offers to track your recruiting journey")
      } actions: {
        if let onAddOffer {
          Button("Log Your First Offer", action: onAddOffer)
        }
      }
    }
  }
}

#Preview("No Data") {
  OfferEmptyState(isFilteredEmpty: false, onClearFilters: nil)
}

#Preview("Filtered Empty") {
  OfferEmptyState(isFilteredEmpty: true, onClearFilters: {})
}
