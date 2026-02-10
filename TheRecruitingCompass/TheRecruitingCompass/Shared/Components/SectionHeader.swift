import SwiftUI

/// A reusable section header with consistent styling and accessibility traits.
struct SectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.headline)
      .foregroundStyle(.primary)
      .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  VStack(alignment: .leading, spacing: 16) {
    SectionHeader(title: "Contact Information")
    SectionHeader(title: "Statistics")
    SectionHeader(title: "Recent Activity")
  }
  .padding()
}
