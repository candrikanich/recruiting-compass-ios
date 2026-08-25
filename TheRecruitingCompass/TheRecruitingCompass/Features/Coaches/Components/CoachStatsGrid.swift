import SwiftUI

/// Three ringed KPI cards (Days Since / Interactions / Preferred), driven by
/// `CoachInsights` — matching the coach-detail Figma frame. Rings are decorative
/// (not proportional to a target), per the design spec.
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
    let value = insights.daysSinceContact.map { "\($0)" } ?? "—"
    return card(
      label: "Days Since",
      value: value,
      valueColor: overdue ? Color.Brand.red600 : .primary,
      ringColor: overdue ? Color.Brand.red500 : Color.Brand.slate500,
      highlighted: overdue
    ) {
      if overdue {
        Text("OVERDUE")
          .font(.caption2.bold())
          .foregroundStyle(.white)
          .padding(.horizontal, 6).padding(.vertical, 2)
          .background(Color.Brand.red500)
          .clipShape(Capsule())
      }
    }
  }

  @ViewBuilder private var interactionsCard: some View {
    card(
      label: "Interactions",
      value: "\(insights.totalInteractions)",
      valueColor: .primary,
      ringColor: Color.Brand.blue500,
      highlighted: false
    ) {
      Text("\(insights.totalInteractions) logged")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder private var preferredCard: some View {
    card(
      label: "Preferred",
      value: insights.preferredChannel?.displayName ?? "—",
      valueColor: .primary,
      ringColor: Color.Brand.orange500,
      highlighted: false
    ) {
      Text("\(insights.responseRate)% rate")
        .font(.caption2)
        .foregroundStyle(Color.Brand.emerald600)
    }
  }

  @ViewBuilder
  private func card<Sub: View>(
    label: LocalizedStringKey, value: String, valueColor: Color, ringColor: Color,
    highlighted: Bool, @ViewBuilder sub: () -> Sub
  ) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(.caption2.bold())
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)

      HStack(alignment: .center, spacing: 6) {
        VStack(alignment: .leading, spacing: 2) {
          Text(value)
            .font(sizeCategory.isAccessibilityCategory ? .title3.bold() : .title2.bold())
            .foregroundStyle(valueColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          sub()
        }
        Spacer(minLength: 0)
        Circle()
          .stroke(ringColor, lineWidth: 3)
          .frame(width: 28, height: 28)
          .accessibilityHidden(true)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
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
      daysSinceContact: 3, isOverdue: false, totalInteractions: 5,
      sent: 3, received: 2, responseRate: 40, preferredChannel: .email))
  }
  .padding()
}
