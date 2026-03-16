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

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  private var icon: String {
    if isFilteredEmpty { return "magnifyingglass" }
    if noSchools { return "building.2" }
    return "person.2.slash"
  }

  private var title: String {
    if isFilteredEmpty { return "No matching coaches" }
    if noSchools { return "Add schools first" }
    return "No coaches yet"
  }

  private var subtitle: String {
    if isFilteredEmpty { return "Try adjusting your search or filters" }
    if noSchools { return "Coaches are added through school pages. Add a school to start tracking coaches there." }
    return "Visit a school's page to add coaches from their staff."
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(title)
        .font(.title3)
        .fontWeight(.semibold)

      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if isFilteredEmpty, let onClearFilters {
        Button("Clear Filters") {
          onClearFilters()
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .background(Color.accentBlue)
        .clipShape(Capsule())
        .accessibilityLabel("Clear filters")
        .accessibilityHint("Removes all active filters and search text")
      } else if !isFilteredEmpty && !noSchools, let onAddCoach {
        Button(action: onAddCoach) {
          Text("Add Your First Coach")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .accessibilityLabel("Add your first coach")
        .accessibilityHint("Opens the form to add a coach")
      }
    }
    .padding(32)
    .frame(maxWidth: .infinity)
  }
}

#Preview {
  VStack {
    CoachEmptyState(isFilteredEmpty: false, noSchools: false, onClearFilters: nil)
    Divider()
    CoachEmptyState(isFilteredEmpty: false, noSchools: true, onClearFilters: nil)
    Divider()
    CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
  }
}
