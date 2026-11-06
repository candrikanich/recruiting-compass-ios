import SwiftUI

/// Outreach History & Analytics: Sent/Received + Response Rate bars and a
/// response-rate ring gauge, driven by `CoachInsights` — matching the frame.
struct CoachAnalyticsCard: View {
  let insights: CoachInsights

  private var sentFraction: CGFloat {
    let total = insights.sent + insights.received
    guard total > 0 else { return 0 }
    return CGFloat(insights.sent) / CGFloat(total)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Text("Outreach History & Analytics").font(.brand(.subheadline, weight: .bold))
          Spacer()
          Text("All Time").font(.brand(.caption)).foregroundStyle(Color.accentPrimary)
        }

        metricRow(label: "Sent / Received", value: "\(insights.sent)/\(insights.received)") {
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule().fill(Color.Brand.emerald500)
              Capsule().fill(Color.Brand.forest500).frame(width: geo.size.width * sentFraction)
            }
          }
          .frame(height: 6)
        }

        metricRow(label: "Response Rate", value: "\(insights.responseRate)%") {
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule().fill(Color(uiColor: .systemGray5))
              Capsule().fill(Color.Brand.emerald500)
                .frame(width: geo.size.width * CGFloat(insights.responseRate) / 100)
            }
          }
          .frame(height: 6)
        }
      }

      gauge
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "Outreach analytics. Sent \(insights.sent), received \(insights.received). Response rate \(insights.responseRate) percent.")
  }

  @ViewBuilder
  private func metricRow<Bar: View>(label: LocalizedStringKey, value: String,
                                    @ViewBuilder bar: () -> Bar) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(label).font(.brand(.footnote)).foregroundStyle(.secondary)
        Spacer()
        Text(value).font(.brand(.footnote, weight: .bold))
      }
      bar()
    }
  }

  @ViewBuilder private var gauge: some View {
    VStack(spacing: 4) {
      ZStack {
        Circle().stroke(Color(uiColor: .systemGray5), lineWidth: 6)
        Circle()
          .trim(from: 0, to: CGFloat(insights.responseRate) / 100)
          .stroke(Color.Brand.emerald500, style: StrokeStyle(lineWidth: 6, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text("\(insights.responseRate)%").font(.brand(.caption, weight: .bold))
      }
      .frame(width: 56, height: 56)
      Text(insights.responseRate >= 50 ? "Great Progress" : "Keep going")
        .font(.brand(.caption2))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  CoachAnalyticsCard(insights: CoachInsights(
    daysSinceContact: 3, isOverdue: false, totalInteractions: 2,
    sent: 1, received: 1, responseRate: 100, preferredChannel: .phoneCall))
  .padding()
}
