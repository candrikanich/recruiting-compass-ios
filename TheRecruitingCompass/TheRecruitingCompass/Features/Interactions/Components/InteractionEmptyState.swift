import SwiftUI

struct InteractionEmptyState: View {
  let isFilteredEmpty: Bool
  let noCoaches: Bool
  let onClearFilters: (() -> Void)?
  var onAddInteraction: (() -> Void)?

  init(
    isFilteredEmpty: Bool,
    noCoaches: Bool = false,
    onClearFilters: (() -> Void)?,
    onAddInteraction: (() -> Void)? = nil
  ) {
    self.isFilteredEmpty = isFilteredEmpty
    self.noCoaches = noCoaches
    self.onClearFilters = onClearFilters
    self.onAddInteraction = onAddInteraction
  }

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 60
  }

  // MARK: - Computed Properties

  private var icon: String {
    if isFilteredEmpty { return "magnifyingglass" }
    if noCoaches { return "person.2.slash" }
    return "bubble.left.and.bubble.right.fill"
  }

  private var title: String {
    if isFilteredEmpty { return "No interactions match your filters" }
    if noCoaches { return "Add a coach first" }
    return "No interactions yet"
  }

  private var subtitle: String {
    if isFilteredEmpty { return "Try adjusting your search or filters" }
    if noCoaches { return "Interactions are linked to coaches. Visit a school's page to add coaches to your list." }
    return "Start logging your recruiting communications with coaches."
  }

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundStyle(.gray.opacity(0.5))
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text(title)
          .font(.headline)
          .foregroundStyle(.primary)

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      if isFilteredEmpty, let onClearFilters {
        Button {
          onClearFilters()
        } label: {
          Text("Clear Filters")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(minHeight: 44)
            .background(Color.blue)
            .clipShape(.rect(cornerRadius: 8))
        }
        .accessibilityLabel("Clear all filters")
      } else if !isFilteredEmpty && !noCoaches, let onAddInteraction {
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
}

#Preview("No Data") {
  InteractionEmptyState(
    isFilteredEmpty: false,
    onClearFilters: nil
  )
}

#Preview("No Coaches") {
  InteractionEmptyState(
    isFilteredEmpty: false,
    noCoaches: true,
    onClearFilters: nil
  )
}

#Preview("Filtered Empty") {
  InteractionEmptyState(
    isFilteredEmpty: true,
    onClearFilters: {}
  )
}
