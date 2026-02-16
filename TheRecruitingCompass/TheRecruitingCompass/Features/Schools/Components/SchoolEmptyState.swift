import SwiftUI

struct SchoolEmptyState: View {
  let isFiltered: Bool
  let onClearFilters: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var iconSize: CGFloat {
    sizeCategory.isAccessibilityCategory ? 72 : 64
  }

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: isFiltered ? "line.3.horizontal.decrease.circle" : "building.2")
        .font(.system(size: iconSize))
        .foregroundColor(.secondary)
        .accessibilityHidden(true)

      Text(isFiltered ? "No matching schools" : "No schools found")
        .font(.title2)
        .fontWeight(.semibold)
        .accessibilityAddTraits(.isHeader)

      Text(isFiltered ? "Try adjusting your filters" : "Add your first school to get started")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      if isFiltered {
        Button(action: onClearFilters) {
          Text("Clear Filters")
            .fontWeight(.semibold)
            .padding()
            .frame(minWidth: 200, minHeight: 44)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Clear all filters")
        .accessibilityHint("Double tap to remove all active filters")
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
