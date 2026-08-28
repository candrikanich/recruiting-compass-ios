import SwiftUI

struct SchoolEmptyState: View {
  let isFiltered: Bool
  let onClearFilters: () -> Void
  var onAddSchool: (() -> Void)?

  var body: some View {
    ListEmptyState(
      isFilteredEmpty: isFiltered,
      filtered: .init(
        icon: "line.3.horizontal.decrease.circle",
        title: String(localized: "No matching schools"),
        message: String(localized: "Try adjusting your filters"),
        actionTitle: String(localized: "Clear Filters"),
        actionHint: String(localized: "Removes all active filters"),
        action: onClearFilters
      ),
      empty: .init(
        icon: "building.2",
        title: String(localized: "No schools found"),
        message: String(localized: "Add your first school to get started"),
        actionTitle: onAddSchool != nil ? String(localized: "Add Your First School") : nil,
        actionHint: String(localized: "Opens the form to add a school"),
        action: onAddSchool
      )
    )
  }
}

#Preview {
  VStack(spacing: 40) {
    SchoolEmptyState(isFiltered: false, onClearFilters: {}, onAddSchool: {})
    SchoolEmptyState(isFiltered: true, onClearFilters: {})
  }
}
