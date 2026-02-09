import SwiftUI

/// A reusable header component for displaying filtered results with active filter count.
struct FilteredResultsHeader: View {
  let resultCount: Int
  let itemName: String
  let activeFilterCount: Int

  init(resultCount: Int, itemName: String = "item", activeFilterCount: Int = 0) {
    self.resultCount = resultCount
    self.itemName = itemName
    self.activeFilterCount = activeFilterCount
  }

  private var resultText: String {
    "\(resultCount) \(resultCount == 1 ? itemName : "\(itemName)s")"
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
    .accessibilityLabel("\(resultCount) \(itemName)\(resultCount == 1 ? "" : "s"), \(activeFilterCount) filters active")
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
      activeFilterCount: 1
    )
  }
  .padding()
}
