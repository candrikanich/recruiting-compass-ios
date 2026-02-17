import SwiftUI

struct OfferFilterBar: View {
  @Binding var filters: OfferFilters

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Picker("Status", selection: $filters.status) {
          Text("All Statuses").tag(nil as OfferStatus?)
          ForEach(OfferStatus.allCases, id: \.self) { status in
            Text(status.displayName).tag(status as OfferStatus?)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Filter by status")
        .accessibilityHint("Double tap to choose a status filter")

        Picker("Type", selection: $filters.offerType) {
          Text("All Types").tag(nil as OfferType?)
          ForEach(OfferType.allCases, id: \.self) { type in
            Text(type.displayName).tag(type as OfferType?)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Filter by offer type")
        .accessibilityHint("Double tap to choose an offer type filter")
      }

      HStack(spacing: 8) {
        Picker("Sort By", selection: $filters.sortBy) {
          ForEach(OfferSortField.allCases, id: \.self) { field in
            Text(field.displayName).tag(field)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Sort by field")
        .accessibilityHint("Double tap to choose sort field")

        Picker("Direction", selection: $filters.sortDirection) {
          ForEach(SortDirection.allCases, id: \.self) { dir in
            Text(dir.displayName).tag(dir)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Sort direction")
        .accessibilityHint("Double tap to change sort direction")
      }
    }
    .padding(.horizontal, 16)
  }
}
