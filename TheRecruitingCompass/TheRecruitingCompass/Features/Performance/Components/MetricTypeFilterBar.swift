import SwiftUI

struct MetricTypeFilterBar: View {
  let availableTypes: [MetricType]
  @Binding var selectedType: MetricType?

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(availableTypes) { type in
          Button {
            selectedType = type
          } label: {
            Text(type.displayName)
              .font(.subheadline)
              .fontWeight(.semibold)
              .padding(.horizontal, 12)
              .padding(.vertical, 10)
              .background(isSelected(type) ? Color.accentBlue : Color(.systemGray6))
              .foregroundStyle(isSelected(type) ? .white : .primary)
              .clipShape(Capsule())
          }
          .frame(minHeight: 44)
          .accessibilityLabel(String(localized: "\(type.displayName) filter"))
          .accessibilityHint(isSelected(type) ? "Currently selected" : "Double tap to filter by \(type.displayName)")
          .accessibilityAddTraits(isSelected(type) ? .isSelected : [])
        }
      }
      .padding(.horizontal, 16)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(String(localized: "Metric type filters"))
    }
    .scrollIndicators(.hidden)
  }

  private func isSelected(_ type: MetricType) -> Bool {
    selectedType == type
  }
}
