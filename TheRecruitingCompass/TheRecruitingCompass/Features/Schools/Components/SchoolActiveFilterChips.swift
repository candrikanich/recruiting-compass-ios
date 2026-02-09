import SwiftUI

struct SchoolActiveFilterChips: View {
  @Binding var filters: SchoolFilters
  let onClearAll: () -> Void

  @Environment(\.sizeCategory) private var sizeCategory

  private var chipHeight: CGFloat {
    sizeCategory.isAccessibilityCategory ? 44 : 36
  }

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(activeFilters, id: \.label) { filter in
          activeChip(label: filter.label, onRemove: filter.onRemove)
        }

        if !activeFilters.isEmpty {
          clearAllButton
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
    }
    .background(Color(.systemGroupedBackground))
  }

  private var activeFilters: [(label: String, onRemove: () -> Void)] {
    var result: [(label: String, onRemove: () -> Void)] = []

    if !filters.searchText.isEmpty {
      result.append(("Search: \(filters.searchText)", { filters.searchText = "" }))
    }

    if let division = filters.division {
      result.append((division.displayName, { filters.division = nil }))
    }

    if let status = filters.status {
      result.append((status.displayName, { filters.status = nil }))
    }

    if let state = filters.state {
      result.append((state, { filters.state = nil }))
    }

    if filters.isFavoritesOnly {
      result.append(("Favorites", { filters.isFavoritesOnly = false }))
    }

    if let tier = filters.priorityTier {
      result.append((tier.displayName, { filters.priorityTier = nil }))
    }

    if filters.fitScoreMin != nil || filters.fitScoreMax != nil {
      let minScore = Int(filters.fitScoreMin ?? 0)
      let maxScore = Int(filters.fitScoreMax ?? 100)
      result.append(("Fit: \(minScore)-\(maxScore)", {
        filters.fitScoreMin = nil
        filters.fitScoreMax = nil
      }))
    }

    if let maxDistance = filters.maxDistance {
      result.append(("Within \(Int(maxDistance))mi", { filters.maxDistance = nil }))
    }

    return result
  }

  private func activeChip(label: String, onRemove: @escaping () -> Void) -> some View {
    HStack(spacing: 4) {
      Text(label)
        .font(.subheadline)
        .fontWeight(.medium)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .font(.caption)
          .accessibilityHidden(true)
      }
      .accessibilityLabel("Remove \(label) filter")
      .accessibilityHint("Double tap to remove this filter")
    }
    .foregroundColor(.white)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(minHeight: chipHeight)
    .background(Color.blue)
    .clipShape(Capsule())
    .accessibilityElement(children: .combine)
  }

  private var clearAllButton: some View {
    Button(action: onClearAll) {
      Text("Clear all")
        .font(.subheadline)
        .fontWeight(.semibold)
    }
    .foregroundColor(.red)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .frame(minHeight: chipHeight)
    .background(Color(.systemGray6))
    .clipShape(Capsule())
    .accessibilityLabel("Clear all filters")
    .accessibilityHint("Double tap to remove all active filters")
  }
}

#Preview {
  SchoolActiveFilterChips(
    filters: .constant(SchoolFilters(
      searchText: "Stanford",
      division: .d1,
      isFavoritesOnly: true,
      fitScoreMin: 70,
      maxDistance: 200
    )),
    onClearAll: {}
  )
}
