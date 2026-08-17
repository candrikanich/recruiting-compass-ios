import SwiftUI

struct SchoolEmptyState: View {
  let isFiltered: Bool
  let onClearFilters: () -> Void
  var onAddSchool: (() -> Void)?

  private var icon: String {
    isFiltered ? "line.3.horizontal.decrease.circle" : "building.2"
  }

  private var title: String {
    isFiltered ? String(localized: "No matching schools") : String(localized: "No schools found")
  }

  private var message: String {
    isFiltered
      ? String(localized: "Try adjusting your filters")
      : String(localized: "Add your first school to get started")
  }

  private var actionTitle: String? {
    if isFiltered { return String(localized: "Clear Filters") }
    return onAddSchool != nil ? String(localized: "Add Your First School") : nil
  }

  private var actionHint: String? {
    isFiltered
      ? String(localized: "Removes all active filters")
      : String(localized: "Opens the form to add a school")
  }

  private var action: (() -> Void)? {
    isFiltered ? onClearFilters : onAddSchool
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

#Preview {
  VStack(spacing: 40) {
    SchoolEmptyState(isFiltered: false, onClearFilters: {}, onAddSchool: {})
    SchoolEmptyState(isFiltered: true, onClearFilters: {})
  }
}
