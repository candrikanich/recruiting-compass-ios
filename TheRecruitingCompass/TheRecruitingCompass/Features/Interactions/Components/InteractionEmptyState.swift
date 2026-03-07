import SwiftUI

struct InteractionEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddInteraction: (() -> Void)? = nil

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 60
  }

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
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
      } else if !isFilteredEmpty, let onAddInteraction {
        Button(action: onAddInteraction) {
          Text("Log Your First Interaction")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .accessibilityLabel("Log your first interaction")
        .accessibilityHint("Opens the form to log an interaction")
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity)
  }

  // MARK: - Computed Properties

  private var icon: String {
    isFilteredEmpty ? "magnifyingglass" : "bubble.left.and.bubble.right.fill"
  }

  private var title: String {
    isFilteredEmpty ? "No interactions match your filters" : "No interactions yet"
  }

  private var subtitle: String {
    isFilteredEmpty
      ? "Try adjusting your search or filters"
      : "Start logging your recruiting communications"
  }

}

#Preview("No Data") {
  InteractionEmptyState(
    isFilteredEmpty: false,
    onClearFilters: nil
  )
}

#Preview("Filtered Empty") {
  InteractionEmptyState(
    isFilteredEmpty: true,
    onClearFilters: {}
  )
}
