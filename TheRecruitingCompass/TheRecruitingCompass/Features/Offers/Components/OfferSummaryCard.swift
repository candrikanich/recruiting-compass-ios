import SwiftUI

struct OfferSummaryCard: View {
  let title: String
  let count: Int
  let color: Color

  var body: some View {
    VStack(spacing: 4) {
      Text("\(count)")
        .font(.title2)
        .bold()
        .foregroundStyle(color)

      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(color.opacity(0.1))
    .clipShape(.rect(cornerRadius: 10))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(count) \(title) offer\(count == 1 ? "" : "s")")
    .accessibilityAddTraits(.isHeader)
  }
}
