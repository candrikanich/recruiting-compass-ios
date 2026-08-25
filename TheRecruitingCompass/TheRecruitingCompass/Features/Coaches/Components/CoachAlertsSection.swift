import SwiftUI

/// Conditional alert banners (Outreach Overdue / Channel Preference). Either,
/// both, or neither may show — matching the coach-detail Figma frame.
struct CoachAlertsSection: View {
  let insights: CoachInsights

  var body: some View {
    VStack(spacing: 12) {
      if insights.overdueAlert, let days = insights.daysSinceContact {
        banner(
          icon: "exclamationmark.triangle.fill",
          tint: Color.Brand.red600, bg: Color.errorBackground, border: Color.errorBorder,
          title: "Urgent: Outreach Overdue",
          message: "No contact in \(days) days – reach out immediately to maintain connection.")
      }
      if insights.channelPreferenceAlert, let channel = insights.preferredChannel {
        banner(
          icon: "info.circle.fill",
          tint: Color.Brand.blue600, bg: Color.Brand.blue100, border: Color.Brand.blue100,
          title: "Channel Preference detected",
          message: "Prefers responding via \(channel.displayName).")
      }
    }
  }

  @ViewBuilder
  private func banner(icon: String, tint: Color, bg: Color, border: Color,
                      title: LocalizedStringKey, message: LocalizedStringKey) -> some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: icon)
        .foregroundStyle(.white)
        .frame(width: 28, height: 28)
        .background(tint)
        .clipShape(Circle())
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.subheadline.bold()).foregroundStyle(tint)
        Text(message).font(.footnote).foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(bg)
    .overlay(RoundedRectangle(cornerRadius: 12).stroke(border, lineWidth: 1))
    .clipShape(.rect(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }
}
