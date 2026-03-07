import SwiftUI

struct OfferEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddOffer: (() -> Void)?

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundColor(.gray.opacity(0.5))
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundColor(.primary)

        Text(subtitle)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      if isFilteredEmpty, let onClearFilters {
        Button {
          onClearFilters()
        } label: {
          Text("Clear Filters")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(Color.blue)
            .cornerRadius(8)
        }
        .accessibilityLabel("Clear all filters")
        .accessibilityHint("Double tap to remove all active filters")
      } else if !isFilteredEmpty, let onAddOffer {
        Button(action: onAddOffer) {
          Text("Log Your First Offer")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .accessibilityLabel("Log your first offer")
        .accessibilityHint("Opens the form to log an offer")
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(isFilteredEmpty ? "No offers match your filters" : "No offers yet")
  }

  private var icon: String {
    isFilteredEmpty ? "magnifyingglass" : "doc.text.fill"
  }

  private var title: String {
    isFilteredEmpty ? "No offers match your filters" : "No offers yet"
  }

  private var subtitle: String {
    isFilteredEmpty
      ? "Try adjusting your search or filters"
      : "Start logging your scholarship offers to track your recruiting journey"
  }
}

#Preview("No Data") {
  OfferEmptyState(isFilteredEmpty: false, onClearFilters: nil)
}

#Preview("Filtered Empty") {
  OfferEmptyState(isFilteredEmpty: true, onClearFilters: {})
}
