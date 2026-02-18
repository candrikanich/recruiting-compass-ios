import SwiftUI

struct DocumentFilterBar: View {
  @Binding var searchQuery: String
  @Binding var sortBy: DocumentSortOption
  @Binding var viewMode: DocumentViewMode
  let hasActiveFilters: Bool
  let activeFilterCount: Int
  let onFilterTapped: () -> Void
  let onClearFilters: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      HStack(spacing: 12) {
        TextField("Search title or description...", text: $searchQuery)
          .textFieldStyle(.roundedBorder)
          .accessibilityLabel("Search documents")
          .accessibilityHint("Filters by title or description")

        Menu {
          ForEach(DocumentSortOption.allCases, id: \.self) { option in
            Button(option.label) {
              sortBy = option
            }
          }
        } label: {
          HStack {
            Text(sortBy.label)
              .lineLimit(1)
            Image(systemName: "chevron.down")
              .font(.caption2)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(.systemGray5))
          .cornerRadius(8)
        }
        .accessibilityLabel("Sort documents")
        .accessibilityHint("Choose sort order")
      }

      HStack {
        Button {
          onFilterTapped()
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text("Filter")
            if activeFilterCount > 0 {
              Text("(\(activeFilterCount))")
                .foregroundStyle(.secondary)
            }
          }
          .font(.subheadline)
        }
        .accessibilityLabel(activeFilterCount > 0 ? "Filter documents. \(activeFilterCount) filters active." : "Filter documents")

        Spacer()

        HStack(spacing: 4) {
          Button {
            viewMode = .grid
          } label: {
            Image(systemName: "square.grid.2x2")
              .frame(width: 44, height: 44)
              .foregroundStyle(viewMode == .grid ? .white : .secondary)
              .background(viewMode == .grid ? Color.blue : Color(.systemGray5))
              .cornerRadius(8)
          }
          .accessibilityLabel("Grid view")
          .accessibilityAddTraits(viewMode == .grid ? .isSelected : [])

          Button {
            viewMode = .list
          } label: {
            Image(systemName: "list.bullet")
              .frame(width: 44, height: 44)
              .foregroundStyle(viewMode == .list ? .white : .secondary)
              .background(viewMode == .list ? Color.blue : Color(.systemGray5))
              .cornerRadius(8)
          }
          .accessibilityLabel("List view")
          .accessibilityAddTraits(viewMode == .list ? .isSelected : [])
        }
      }

      if hasActiveFilters {
        Button("Clear filters", role: .destructive) {
          onClearFilters()
        }
        .font(.caption)
      }
    }
    .padding()
    .background(Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
  }
}
