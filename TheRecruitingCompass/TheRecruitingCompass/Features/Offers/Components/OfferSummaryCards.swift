import SwiftUI

struct OfferSummaryCards: View {
  let acceptedCount: Int
  let pendingCount: Int
  let declinedCount: Int

  var body: some View {
    HStack(spacing: 12) {
      OfferSummaryCard(title: String(localized: "Accepted"), count: acceptedCount, color: OfferStatus.accepted.statusColor)
      OfferSummaryCard(title: String(localized: "Pending"), count: pendingCount, color: OfferStatus.pending.statusColor)
      OfferSummaryCard(title: String(localized: "Declined"), count: declinedCount, color: OfferStatus.declined.statusColor)
    }
    .padding(.horizontal, 16)
  }
}

#Preview {
  OfferSummaryCards(acceptedCount: 2, pendingCount: 5, declinedCount: 1)
}
