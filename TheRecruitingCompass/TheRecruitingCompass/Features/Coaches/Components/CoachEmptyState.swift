import SwiftUI

struct CoachEmptyState: View {
  let isFilteredEmpty: Bool
  let onClearFilters: (() -> Void)?
  var onAddCoach: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 56 : 48
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: isFilteredEmpty ? "magnifyingglass" : "person.2.slash")
        .font(.system(size: iconSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(isFilteredEmpty ? "No matching coaches" : "No coaches yet")
        .font(.title3)
        .fontWeight(.semibold)

      Text(isFilteredEmpty
        ? "Try adjusting your search or filters"
        : "Add coaches from your tracked schools to get started")
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
      } else if !isFilteredEmpty, let onAddCoach {
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
    CoachEmptyState(isFilteredEmpty: false, onClearFilters: nil)
    Divider()
    CoachEmptyState(isFilteredEmpty: true, onClearFilters: {})
  }
}
