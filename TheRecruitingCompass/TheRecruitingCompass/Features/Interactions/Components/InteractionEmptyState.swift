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

  private var icon: String {
    if isFilteredEmpty { return "magnifyingglass" }
    if noCoaches { return "person.2.slash" }
    return "bubble.left.and.bubble.right.fill"
  }

  private var title: String {
    if isFilteredEmpty { return String(localized: "No interactions match your filters") }
    if noCoaches { return String(localized: "Add a coach first") }
    return String(localized: "No interactions yet")
  }

  private var subtitle: String {
    if isFilteredEmpty { return String(localized: "Try adjusting your search or filters") }
    if noCoaches {
      return String(localized: "Interactions are linked to coaches. Visit a school's page to add coaches to your list.")
    }
    return String(localized: "Start logging your recruiting communications with coaches.")
  }

  private var actionTitle: String? {
    if isFilteredEmpty { return onClearFilters != nil ? String(localized: "Clear Filters") : nil }
    if noCoaches { return nil }
    return onAddInteraction != nil ? String(localized: "Log Your First Interaction") : nil
  }

  private var actionHint: String? {
    if isFilteredEmpty { return String(localized: "Removes all active filters and search text") }
    return String(localized: "Opens the form to log an interaction")
  }

  private var action: (() -> Void)? {
    if isFilteredEmpty { return onClearFilters }
    if noCoaches { return nil }
    return onAddInteraction
  }

  var body: some View {
    EmptyStateView(
      icon: icon,
      title: title,
      message: subtitle,
      actionTitle: actionTitle,
      actionHint: actionHint,
      action: action
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
