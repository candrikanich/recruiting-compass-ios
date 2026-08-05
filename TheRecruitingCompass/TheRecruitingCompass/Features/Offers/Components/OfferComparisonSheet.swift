import SwiftUI

struct OfferComparisonSheet: View {
  let offers: [Offer]
  let schoolNameFor: (String) -> String

  var body: some View {
    NavigationStack {
      ScrollView(.horizontal) {
        LazyHStack(alignment: .top, spacing: 16) {
          ForEach(offers) { offer in
            comparisonColumn(offer)
          }
        }
        .padding(16)
      }
      .navigationTitle("Compare Offers")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func comparisonColumn(_ offer: Offer) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(schoolNameFor(offer.schoolId))
        .font(.headline)
        .lineLimit(2)
        .accessibilityAddTraits(.isHeader)

      Divider()
        .accessibilityHidden(true)

      comparisonRow(String(localized: "Type"), value: offer.offerType.displayName)
      comparisonRow(String(localized: "Status"), value: offer.status.displayName)
      comparisonRow(String(localized: "Percentage"), value: offer.formattedPercentage ?? String(localized: "N/A"))
      comparisonRow(String(localized: "Amount"), value: offer.formattedAmount ?? String(localized: "N/A"))
      comparisonRow(String(localized: "Offer Date"), value: DateFormatting.mediumDate(offer.displayOfferDate))

      if let deadline = offer.displayDeadlineDate {
        comparisonRow(String(localized: "Deadline"), value: DateFormatting.mediumDate(deadline))
      } else {
        comparisonRow(String(localized: "Deadline"), value: String(localized: "None"))
      }
    }
    .frame(width: 200)
    .padding(16)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 12))
  }

  private func comparisonRow(_ label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(value)
        .font(.subheadline)
        .foregroundStyle(.primary)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(label): \(value)"))
  }
}
