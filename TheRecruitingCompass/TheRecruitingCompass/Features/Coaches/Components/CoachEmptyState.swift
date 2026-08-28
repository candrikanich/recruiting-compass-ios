import SwiftUI

struct CoachEmptyState: View {
  let isFilteredEmpty: Bool
  let noSchools: Bool
  let onClearFilters: (() -> Void)?
  var onAddCoach: (() -> Void)?

  init(
    isFilteredEmpty: Bool,
    noSchools: Bool = false,
    onClearFilters: (() -> Void)?,
    onAddCoach: (() -> Void)? = nil
  ) {
    self.isFilteredEmpty = isFilteredEmpty
    self.noSchools = noSchools
    self.onClearFilters = onClearFilters
    self.onAddCoach = onAddCoach
  }

  var body: some View {
    ListEmptyState(
      isFilteredEmpty: isFilteredEmpty,
      isBlocked: noSchools,
      filtered: .init(
        icon: "magnifyingglass",
        title: String(localized: "No matching coaches"),
        message: String(localized: "Try adjusting your search or filters"),
        actionTitle: onClearFilters != nil ? String(localized: "Clear Filters") : nil,
        actionHint: String(localized: "Removes all active filters and search text"),
        action: onClearFilters
      ),
      blocked: .init(
        icon: "building.2",
        title: String(localized: "Add schools first"),
        message: String(localized: "Coaches are added through school pages. Add a school to start tracking coaches there.")
      ),
      empty: .init(
        icon: "person.2.slash",
        title: String(localized: "No coaches yet"),
        message: String(localized: "Visit a school's page to add coaches from their staff."),
        actionTitle: onAddCoach != nil ? String(localized: "Add Your First Coach") : nil,
        actionHint: String(localized: "Opens the form to add a coach"),
        action: onAddCoach
      )
    )
  }
}

#Preview {
  VStack {
    CoachEmptyState(isFilteredEmpty: false, noSchools: false, onClearFilters: nil, onAddCoach: {})
    Divider()
    CoachEmptyState(isFilteredEmpty: false, noSchools: true, onClearFilters: nil)
    Divider()
    CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
  }
}
