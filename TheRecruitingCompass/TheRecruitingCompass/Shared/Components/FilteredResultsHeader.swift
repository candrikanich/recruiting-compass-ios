import SwiftUI

/// A reusable header component for displaying filtered results with active filter count.
struct FilteredResultsHeader: View {
  let resultCount: Int
  let itemName: String
  let itemNamePlural: String?
  let activeFilterCount: Int

  init(resultCount: Int, itemName: String = "item", itemNamePlural: String? = nil, activeFilterCount: Int = 0) {
    self.resultCount = resultCount
    self.itemName = itemName
    self.itemNamePlural = itemNamePlural
    self.activeFilterCount = activeFilterCount
  }

  private var pluralName: String {
    itemNamePlural ?? "\(itemName)s"
  }

  private var resultText: String {
    "\(resultCount) \(resultCount == 1 ? itemName : pluralName)"
  }

  private var filterText: String? {
    guard activeFilterCount > 0 else { return nil }
    return "(\(activeFilterCount) \(activeFilterCount == 1 ? "filter" : "filters") active)"
  }

  var body: some View {
    HStack {
      Text(resultText)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundColor(.secondary)

      if let filterText = filterText {
        Text(filterText)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(resultCount) \(resultCount == 1 ? itemName : pluralName), \(activeFilterCount) filters active")
  }
}

#Preview {
  VStack(spacing: 16) {
    FilteredResultsHeader(
      resultCount: 15,
      itemName: "school",
      activeFilterCount: 3
    )

    FilteredResultsHeader(
      resultCount: 1,
      itemName: "school",
      activeFilterCount: 0
    )

    FilteredResultsHeader(
      resultCount: 42,
      itemName: "coach",
      itemNamePlural: "coaches",
      activeFilterCount: 1
    )
  }
  .padding()
}
