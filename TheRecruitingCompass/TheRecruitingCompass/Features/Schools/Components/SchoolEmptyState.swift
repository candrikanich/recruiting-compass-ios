import SwiftUI

struct SchoolEmptyState: View {
  let isFiltered: Bool
  let onClearFilters: () -> Void
  var onAddSchool: (() -> Void)?

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 64
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "building.2")
        .font(.system(size: iconSize))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text(isFiltered ? String(localized: "No matching schools") : String(localized: "No schools found"))
        .font(.title2)
        .fontWeight(.semibold)
        .accessibilityAddTraits(.isHeader)

      Text(isFiltered ? String(localized: "Try adjusting your filters") : String(localized: "Add your first school to get started"))
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

      if isFiltered {
        Button(action: onClearFilters) {
          Text("Clear Filters")
            .fontWeight(.semibold)
            .padding()
            .frame(minWidth: 200, minHeight: 44)
            .background(Color.blue)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(String(localized: "Clear all filters"))
        .accessibilityHint("Double tap to remove all active filters")
      } else if let onAddSchool {
        Button(action: onAddSchool) {
          Text("Add Your First School")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .padding(.horizontal)
        .accessibilityLabel(String(localized: "Add your first school"))
        .accessibilityHint("Opens the form to add a school")
      }
    }
    .padding(40)
  }
}

#Preview {
  VStack(spacing: 40) {
    SchoolEmptyState(isFiltered: false) {}
    SchoolEmptyState(isFiltered: true) {}
  }
}
