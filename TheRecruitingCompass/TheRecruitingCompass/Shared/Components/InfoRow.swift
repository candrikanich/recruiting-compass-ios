import SwiftUI

/// A reusable row displaying a label-value pair
struct InfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .top) {
      Text(label + ":")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.subheadline)
        .multilineTextAlignment(.trailing)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(label): \(value)"))
  }
}

#Preview {
  VStack(spacing: 12) {
    InfoRow(label: "Campus Address", value: "123 College Ave, Boston, MA 02115")
    InfoRow(label: "Mascot", value: "Eagles")
    InfoRow(label: "Undergrad Size", value: "5,000 students")
  }
  .padding()
}
