import SwiftUI

struct OfferDetailsGrid: View {
  let offerDate: String
  let deadlineDate: String
  let conditions: String?
  let notes: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Offer Details")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], alignment: .leading, spacing: 16) {
        detailItem(label: "Offer Date", value: offerDate)
        detailItem(label: "Deadline Date", value: deadlineDate)
      }

      if let conditions, !conditions.isEmpty {
        detailItem(label: "Conditions", value: conditions)
      }

      if let notes, !notes.isEmpty {
        detailItem(label: "Notes", value: notes)
      }
    }
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .padding(.horizontal)
  }

  private func detailItem(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(value)
        .font(.subheadline)
        .fontWeight(.semibold)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(value)")
  }
}

#Preview {
  OfferDetailsGrid(
    offerDate: "Feb 10, 2026",
    deadlineDate: "Mar 15, 2026",
    conditions: "Must maintain 3.0 GPA",
    notes: "Full athletic scholarship offer"
  )
}
