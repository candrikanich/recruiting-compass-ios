import SwiftUI

struct DocumentMetadataItem: View {
  let label: LocalizedStringKey
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.brand(.caption))
        .foregroundStyle(.secondary)
      Text(value)
        .font(.brand(.subheadline))
        .fontWeight(.medium)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
