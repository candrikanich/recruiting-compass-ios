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

  private var icon: String {
    if isFilteredEmpty { return "magnifyingglass" }
    if noSchools { return "building.2" }
    return "person.2.slash"
  }

  private var title: String {
    if isFilteredEmpty { return String(localized: "No matching coaches") }
    if noSchools { return String(localized: "Add schools first") }
    return String(localized: "No coaches yet")
  }

  private var subtitle: String {
    if isFilteredEmpty { return String(localized: "Try adjusting your search or filters") }
    if noSchools {
      return String(localized: "Coaches are added through school pages. Add a school to start tracking coaches there.")
    }
    return String(localized: "Visit a school's page to add coaches from their staff.")
  }

  private var actionTitle: String? {
    if isFilteredEmpty { return onClearFilters != nil ? String(localized: "Clear Filters") : nil }
    if noSchools { return nil }
    return onAddCoach != nil ? String(localized: "Add Your First Coach") : nil
  }

  private var actionHint: String? {
    if isFilteredEmpty { return String(localized: "Removes all active filters and search text") }
    return String(localized: "Opens the form to add a coach")
  }

  private var action: (() -> Void)? {
    if isFilteredEmpty { return onClearFilters }
    if noSchools { return nil }
    return onAddCoach
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

#Preview {
  VStack {
    CoachEmptyState(isFilteredEmpty: false, noSchools: false, onClearFilters: nil, onAddCoach: {})
    Divider()
    CoachEmptyState(isFilteredEmpty: false, noSchools: true, onClearFilters: nil)
    Divider()
    CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
  }
}
