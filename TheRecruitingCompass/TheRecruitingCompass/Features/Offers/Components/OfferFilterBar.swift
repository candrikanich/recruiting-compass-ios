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
        .accessibilityLabel(statusFilterLabel)
        .accessibilityHint(statusFilterHint)

        Picker("Type", selection: $filters.offerType) {
          Text("All Types").tag(nil as OfferType?)
          ForEach(OfferType.allCases, id: \.self) { type in
            Text(type.displayName).tag(type as OfferType?)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(offerTypeFilterLabel)
        .accessibilityHint(offerTypeFilterHint)
      }

      HStack(spacing: 8) {
        Picker("Sort By", selection: $filters.sortBy) {
          ForEach(OfferSortField.allCases, id: \.self) { field in
            Text(field.displayName).tag(field)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(sortByFieldLabel)
        .accessibilityHint(sortByFieldHint)

        Picker("Direction", selection: $filters.sortDirection) {
          ForEach(SortDirection.allCases, id: \.self) { dir in
            Text(dir.displayName).tag(dir)
          }
        }
        .pickerStyle(.menu)
        .accessibilityLabel(sortDirectionLabel)
        .accessibilityHint(sortDirectionHint)
      }
    }
    .padding(.horizontal, 16)
  }

  var statusFilterLabel: String { String(localized: "Filter by status") }
  var statusFilterHint: String { "Double tap to choose a status filter" }

  var offerTypeFilterLabel: String { String(localized: "Filter by offer type") }
  var offerTypeFilterHint: String { "Double tap to choose an offer type filter" }

  var sortByFieldLabel: String { String(localized: "Sort by field") }
  var sortByFieldHint: String { "Double tap to choose sort field" }

  var sortDirectionLabel: String { String(localized: "Sort direction") }
  var sortDirectionHint: String { "Double tap to change sort direction" }
}
