import SwiftUI

/// Neutral dashboard stat tile (mirrors web DashboardStatsCards.vue): label + muted icon on top,
/// big tabular number below, optional orange badge text such as "3 pending".
struct StatCard: View {
  let title: String
  let count: Int
  var badge: String?
  let icon: String
  let isEnabled: Bool
  let destination: DashboardDestination?

  @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 20

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(.brand(.subheadline, weight: .medium))
          .foregroundStyle(Color.Text.secondary)
        Spacer()
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundStyle(Color.Brand.slate400)
          .accessibilityHidden(true)
      }

      Text("\(count)")
        .font(.brand(.title, weight: .semibold))
        .monospacedDigit()
        .foregroundStyle(Color.Text.primary)

      if let badge {
        Text(badge)
          .font(.brand(.subheadline, weight: .medium))
          .foregroundStyle(Color.Brand.orange700)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.Surface.border, lineWidth: 1))
    .brandShadowSm()
    .opacity(isEnabled ? 1.0 : 0.7)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(title): \(count)"))
    .accessibilityValue(badge ?? "")
    .accessibilityAddTraits(isEnabled ? [.isButton] : [])
    .accessibilityHint(isEnabled ? "Tap to view \(title.lowercased())" : "")
  }
}

#Preview {
  StatCard(
    title: "Offers",
    count: 12,
    badge: "3 pending",
    icon: "trophy",
    isEnabled: true,
    destination: .coaches
  )
  .padding()
}
