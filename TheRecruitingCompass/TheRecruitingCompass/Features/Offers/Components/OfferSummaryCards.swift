import SwiftUI

struct OfferSummaryCards: View {
  let acceptedCount: Int
  let pendingCount: Int
  let declinedCount: Int

  var body: some View {
    HStack(spacing: 12) {
      OfferSummaryCard(title: "Accepted", count: acceptedCount, color: OfferStatus.accepted.statusColor)
      OfferSummaryCard(title: "Pending", count: pendingCount, color: OfferStatus.pending.statusColor)
      OfferSummaryCard(title: "Declined", count: declinedCount, color: OfferStatus.declined.statusColor)
    }
    .padding(.horizontal, 16)
  }
}

private struct OfferSummaryCard: View {
  let title: String
  let count: Int
  let color: Color

  var body: some View {
    VStack(spacing: 4) {
      Text("\(count)")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(color)

      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(color.opacity(0.1))
    .cornerRadius(10)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(count) \(title) offer\(count == 1 ? "" : "s")")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  OfferSummaryCards(acceptedCount: 2, pendingCount: 5, declinedCount: 1)
}
