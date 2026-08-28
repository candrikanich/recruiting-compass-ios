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

  var body: some View {
    ListEmptyState(
      isFilteredEmpty: isFilteredEmpty,
      isBlocked: noCoaches,
      filtered: .init(
        icon: "magnifyingglass",
        title: String(localized: "No interactions match your filters"),
        message: String(localized: "Try adjusting your search or filters"),
        actionTitle: onClearFilters != nil ? String(localized: "Clear Filters") : nil,
        actionHint: String(localized: "Removes all active filters and search text"),
        action: onClearFilters
      ),
      blocked: .init(
        icon: "person.2.slash",
        title: String(localized: "Add a coach first"),
        message: String(localized: "Interactions are linked to coaches. Visit a school's page to add coaches to your list.")
      ),
      empty: .init(
        icon: "bubble.left.and.bubble.right.fill",
        title: String(localized: "No interactions yet"),
        message: String(localized: "Start logging your recruiting communications with coaches."),
        actionTitle: onAddInteraction != nil ? String(localized: "Log Your First Interaction") : nil,
        actionHint: String(localized: "Opens the form to log an interaction"),
        action: onAddInteraction
      )
    )
  }
}

#Preview("No Data") {
  InteractionEmptyState(isFilteredEmpty: false, onClearFilters: nil, onAddInteraction: {})
}

#Preview("No Coaches") {
  InteractionEmptyState(isFilteredEmpty: false, noCoaches: true, onClearFilters: nil)
}

#Preview("Filtered Empty") {
  InteractionEmptyState(isFilteredEmpty: true, onClearFilters: {})
}
