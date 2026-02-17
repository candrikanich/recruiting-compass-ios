import SwiftUI

struct OfferHeaderView: View {
  let status: OfferStatus
  let schoolName: String
  let offerType: OfferType

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        Text(status.displayName)
          .font(.caption)
          .fontWeight(.semibold)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(status.statusColor.opacity(0.15))
          .foregroundStyle(status.statusColor)
          .clipShape(Capsule())
          .accessibilityIdentifier("offer-status-badge")
          .accessibilityLabel("Status: \(status.displayName)")

        Text(schoolName)
          .font(.title2)
          .fontWeight(.bold)
          .accessibilityIdentifier("offer-detail-school-name")
          .accessibilityAddTraits(.isHeader)
      }

      Text(offerType.displayName)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Offer type: \(offerType.displayName)")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(schoolName), Status: \(status.displayName), Offer type: \(offerType.displayName)")
    .accessibilityAddTraits(.isHeader)
  }
}

#Preview {
  OfferHeaderView(
    status: .pending,
    schoolName: "University of Florida",
    offerType: .fullRide
  )
}
