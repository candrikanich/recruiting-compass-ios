import SwiftUI

struct DateRangeToolbar: View {
  @Binding var selectedRange: AnalyticsDateRange
  @Binding var showDatePicker: Bool
  let onRangeSelected: (AnalyticsDateRange) async -> Void

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(AnalyticsDateRange.allPresets, id: \.displayName) { range in
          Button {
            Task {
              await onRangeSelected(range)
            }
          } label: {
            Text(range.displayName)
              .font(.subheadline)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(isSelected(range) ? Color.accentBlue : Color(.secondarySystemBackground))
              .foregroundStyle(isSelected(range) ? .white : Color.darkSlate)
              .clipShape(Capsule())
          }
          .frame(minHeight: 44)
          .accessibilityLabel("Filter by \(range.displayName)")
          .accessibilityHint(isSelected(range) ? "Currently selected" : "Double tap to filter by \(range.displayName)")
          .accessibilityAddTraits(isSelected(range) ? .isSelected : [])
        }

        Button {
          showDatePicker = true
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "calendar")
              .accessibilityHidden(true)
            Text("Custom")
              .font(.subheadline)
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background(isCustomSelected ? Color.accentBlue : Color(.secondarySystemBackground))
          .foregroundStyle(isCustomSelected ? .white : Color.darkSlate)
          .clipShape(Capsule())
        }
        .frame(minHeight: 44)
        .accessibilityLabel("Select custom date range")
        .accessibilityHint(isCustomSelected ? "Currently selected" : "Double tap to select a custom date range")
        .accessibilityAddTraits(isCustomSelected ? .isSelected : [])
      }
      .padding(.horizontal)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("Date range filters")
    }
    .scrollIndicators(.hidden)
  }

  private func isSelected(_ range: AnalyticsDateRange) -> Bool {
    switch (selectedRange, range) {
    case (.last7Days, .last7Days), (.last30Days, .last30Days), (.last90Days, .last90Days):
      return true
    default:
      return false
    }
  }

  private var isCustomSelected: Bool {
    if case .custom = selectedRange { return true }
    return false
  }
}
