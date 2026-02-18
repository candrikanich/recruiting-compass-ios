import SwiftUI

struct DocumentActiveFilterChips: View {
  @Bindable var viewModel: DocumentsListViewModel

  var body: some View {
    FilterChipContainer(
      hasFilters: viewModel.hasActiveFilters,
      style: .outlined,
      onClearAll: { viewModel.clearFilters() }
    ) {
      ForEach(activeFilters, id: \.label) { filter in
        FilterChip(label: filter.label, style: .outlined, onRemove: filter.onRemove)
      }
    }
  }

  private var activeFilters: [(label: String, onRemove: () -> Void)] {
    var result: [(label: String, onRemove: () -> Void)] = []

    if !viewModel.searchQuery.isEmpty {
      let query = viewModel.searchQuery
      result.append(("Search: \(query)", { viewModel.searchQuery = "" }))
    }

    for type in viewModel.selectedTypes.sorted(by: { $0.rawValue < $1.rawValue }) {
      result.append(("Type: \(type.label)", { viewModel.toggleType(type) }))
    }

    if let schoolId = viewModel.selectedSchoolId {
      let name = viewModel.schoolName(for: schoolId)
      result.append(("School: \(name)", { viewModel.selectedSchoolId = nil }))
    }

    if viewModel.showSharedOnly {
      result.append(("Shared only", { viewModel.showSharedOnly = false }))
    }

    return result
  }
}
