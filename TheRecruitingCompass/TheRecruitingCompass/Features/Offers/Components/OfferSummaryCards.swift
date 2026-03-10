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

#Preview {
  OfferSummaryCards(acceptedCount: 2, pendingCount: 5, declinedCount: 1)
}
