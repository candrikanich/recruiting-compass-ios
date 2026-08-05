import SwiftUI

struct FunnelChartView: View {
  let stages: [FunnelStage]
  let title: String

  private var maxValue: Int {
    stages.map(\.value).max() ?? 1
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundStyle(Color.darkSlate)
        .accessibilityAddTraits(.isHeader)

      if stages.isEmpty {
        emptyState
      } else {
        VStack(spacing: 0) {
          ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
            funnelRow(stage: stage, index: index)

            if index < stages.count - 1 {
              conversionArrow(from: stage, to: stages[index + 1])
            }
          }
        }
      }
    }
    .chartCard()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(funnelAccessibilityLabel)
    .accessibilityValue(funnelAccessibilityValue)
  }

  private var funnelAccessibilityLabel: String {
    if stages.isEmpty {
      return String(localized: "\(title) funnel chart. No pipeline data.")
    }
    return String(localized: "\(title) funnel chart with \(stages.count) stages")
  }

  private var funnelAccessibilityValue: String {
    guard !stages.isEmpty else { return "" }
    var parts: [String] = []
    for (index, stage) in stages.enumerated() {
      var part = "\(stage.label): \(stage.value)"
      if index < stages.count - 1 {
        let nextStage = stages[index + 1]
        let rate = stage.value > 0
          ? Int(round(Double(nextStage.value) / Double(stage.value) * 100))
          : 0
        part += " (\(rate)% conversion)"
      }
      parts.append(part)
    }
    return parts.joined(separator: "; ")
  }

  private func funnelRow(stage: FunnelStage, index: Int) -> some View {
    let widthFraction = maxValue > 0 ? CGFloat(stage.value) / CGFloat(maxValue) : 0

    return VStack(spacing: 4) {
      Text(stage.label)
        .font(.subheadline.bold())
        .foregroundStyle(Color.darkSlate)

      HStack {
        Spacer()
        RoundedRectangle(cornerRadius: 8)
          .fill(stage.color.gradient)
          .containerRelativeFrame(.horizontal) { width, _ in
            max(width * widthFraction, 60)
          }
          .frame(height: 44)
          .overlay {
            Text("\(stage.value)")
              .font(.subheadline.bold())
              .foregroundStyle(.white)
          }
        Spacer()
      }
    }
    .padding(.vertical, 4)
  }

  private func conversionArrow(from: FunnelStage, to: FunnelStage) -> some View {
    let rate = from.value > 0
      ? Int(round(Double(to.value) / Double(from.value) * 100))
      : 0

    return HStack(spacing: 4) {
      Spacer()
      Image(systemName: "arrow.down")
        .font(.caption)
        .foregroundStyle(Color.iconGray)
      Text("\(rate)%")
        .font(.caption.bold())
        .foregroundStyle(Color.secondaryText)
      Spacer()
    }
    .padding(.vertical, 2)
  }

  @ViewBuilder
  private var emptyState: some View {
    ChartEmptyStateView(iconName: "chart.bar.doc.horizontal", message: String(localized: "No pipeline data"))
  }
}
