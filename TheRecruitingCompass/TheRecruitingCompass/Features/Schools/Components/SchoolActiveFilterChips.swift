import SwiftUI

struct SchoolActiveFilterChips: View {
  @Binding var filters: SchoolFilters
  let onClearAll: () -> Void

  var body: some View {
    if !activeFilters.isEmpty {
      FilterChipContainer(
        hasFilters: !activeFilters.isEmpty,
        style: .filled,
        onClearAll: onClearAll
      ) {
        ForEach(activeFilters, id: \.label) { filter in
          FilterChip(label: filter.label, style: .filled, onRemove: filter.onRemove)
        }
      }
      .background(Color(.systemGroupedBackground))
    }
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
