import SwiftUI

struct AtAGlanceSummary: View {
  let schoolsWithOffers: String
  let interactionsThisMonth: Int
  let daysUntilGraduation: String

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("At a Glance")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      Divider()

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible())
      ], spacing: 16) {
        MetricCard(
          title: "Schools with Offers",
          value: schoolsWithOffers,
          color: .accentBlue
        )

        MetricCard(
          title: "Interactions This Month",
          value: "\(interactionsThisMonth)",
          color: .accentBlue
        )

        MetricCard(
          title: "Days Until Graduation",
          value: daysUntilGraduation,
          color: .accentBlue
        )
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }
}

#Preview {
  AtAGlanceSummary(
    schoolsWithOffers: "40%",
    interactionsThisMonth: 12,
    daysUntilGraduation: "365"
  )
  .padding()
}
