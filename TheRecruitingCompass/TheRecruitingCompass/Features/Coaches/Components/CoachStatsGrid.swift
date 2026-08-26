import SwiftUI

/// Three KPI cards (Days Since / Interactions / Preferred), driven by
/// `CoachInsights`. Each card is a consistent label / value / sub-line stack.
struct CoachStatsGrid: View {
  let insights: CoachInsights

  @Environment(\.sizeCategory) private var sizeCategory

  private var columns: [GridItem] {
    [GridItem(.flexible(), spacing: 12),
     GridItem(.flexible(), spacing: 12),
     GridItem(.flexible(), spacing: 12)]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: 12) {
      daysSinceCard
      interactionsCard
      preferredCard
    }
  }

  @ViewBuilder private var daysSinceCard: some View {
    let overdue = insights.isOverdue
    card(
      label: "Days Since",
      value: insights.daysSinceContact.map { "\($0)" } ?? "—",
      valueColor: overdue ? Color.Brand.red600 : .primary,
      highlighted: overdue
    ) {
      if overdue {
        subPill("OVERDUE", text: .white, background: Color.Brand.red500)
      } else {
        subPill(daysSinceSubtitle, text: .secondary, background: Color(uiColor: .systemGray5))
      }
    }
  }

  private var daysSinceSubtitle: LocalizedStringKey {
    guard let days = insights.daysSinceContact else { return "no contact" }
    if days == 0 { return "today" }
    return "days ago"
  }

  @ViewBuilder private var interactionsCard: some View {
    card(
      label: "Interactions",
      value: "\(insights.totalInteractions)",
      valueColor: .primary,
      highlighted: false
    ) {
      subPill("\(insights.totalInteractions) logged", text: Color.Brand.blue600, background: Color.Brand.blue100)
    }
  }

  @ViewBuilder private var preferredCard: some View {
    card(
      label: "Preferred",
      value: insights.preferredChannel?.displayName ?? "—",
      valueColor: .primary,
      highlighted: false
    ) {
      subPill("\(insights.responseRate)% rate", text: Color.Brand.emerald600, background: Color.Brand.emerald100)
    }
  }

  @ViewBuilder
  private func subPill(_ text: LocalizedStringKey, text textColor: Color, background: Color) -> some View {
    Text(text)
      .font(.caption2.bold())
      .foregroundStyle(textColor)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 8).padding(.vertical, 3)
      .background(background)
      .clipShape(Capsule())
  }

  @ViewBuilder
  private func card<Sub: View>(
    label: LocalizedStringKey, value: String, valueColor: Color,
    highlighted: Bool, @ViewBuilder sub: () -> Sub
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption2.bold())
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      Text(value)
        .font(sizeCategory.isAccessibilityCategory ? .title3.bold() : .title2.bold())
        .foregroundStyle(valueColor)
        .lineLimit(1)
        .minimumScaleFactor(0.6)

      sub()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(highlighted ? Color.errorBackground : Color(uiColor: .systemGray6))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(highlighted ? Color.errorBorder : Color.clear, lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
  }
}

#Preview {
  VStack {
    CoachStatsGrid(insights: CoachInsights(
      daysSinceContact: 64, isOverdue: true, totalInteractions: 2,
      sent: 1, received: 1, responseRate: 100, preferredChannel: .phoneCall))
    CoachStatsGrid(insights: CoachInsights(
      daysSinceContact: 1, isOverdue: false, totalInteractions: 5,
      sent: 4, received: 1, responseRate: 20, preferredChannel: .email))
  }
  .padding()
}
