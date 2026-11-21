import SwiftUI

/// Dashboard stat tile (mirrors web DashboardStatsCards.vue): label + accent icon chip on top,
/// big tabular number below, optional orange badge text such as "3 pending". A 3 pt brand top border
/// carries the accent; label and icon stay on every tile so color is never the only signal.
struct StatCard: View {
  let title: String
  let count: Int
  var badge: String?
  let icon: String
  let metric: StatMetric
  let isEnabled: Bool
  let destination: DashboardDestination?

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .title3) private var iconSize: CGFloat = 20
  @ScaledMetric(relativeTo: .title3) private var chipSize: CGFloat = 32

  private var accent: StatAccent { metric.accent }

  static func stacksHeader(for size: DynamicTypeSize) -> Bool { size.isAccessibilitySize }

  /// Accessibility sizes stack the chip above the title so the title keeps the full tile width.
  private var headerLayout: AnyLayout {
    Self.stacksHeader(for: dynamicTypeSize)
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
      : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      headerLayout {
        Text(title)
          .font(.brand(.subheadline, weight: .medium))
          .foregroundStyle(Color.Text.secondary)
        if !Self.stacksHeader(for: dynamicTypeSize) { Spacer() }
        Image(systemName: icon)
          .font(.system(size: iconSize))
          .foregroundStyle(accent.icon)
          .frame(width: chipSize, height: chipSize)
          .background(accent.chipFill, in: .rect(cornerRadius: 8))
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
    .overlay(alignment: .top) {
      Rectangle().fill(accent.border).frame(height: 3)
    }
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
    metric: .schools,
    isEnabled: true,
    destination: .coaches
  )
  .padding()
}
