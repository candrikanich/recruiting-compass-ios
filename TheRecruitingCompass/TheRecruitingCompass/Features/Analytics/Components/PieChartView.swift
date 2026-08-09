import SwiftUI

struct PieChartView: View {
  let segments: [PieChartSegment]
  let title: String

  private var total: Int {
    segments.reduce(0) { $0 + $1.value }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
        .foregroundStyle(Color.darkSlate)
        .accessibilityAddTraits(.isHeader)

      if segments.isEmpty {
        emptyState
      } else {
        HStack(spacing: 24) {
          pieRing
            .frame(width: 160, height: 160)

          legendView
        }
        .frame(maxWidth: .infinity)
      }
    }
    .chartCard()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(chartAccessibilityLabel)
    .accessibilityValue(chartAccessibilityValue)
  }

  private var chartAccessibilityLabel: String {
    if segments.isEmpty {
      return String(localized: "\(title) pie chart. No data available.")
    }
    return String(localized: "\(title) pie chart with \(segments.count) segments, \(total) total")
  }

  private var chartAccessibilityValue: String {
    guard !segments.isEmpty, total > 0 else { return "" }
    return segments.map { segment in
      let pct = Int(round(Double(segment.value) / Double(total) * 100))
      return "\(segment.label): \(segment.value) (\(pct)%)"
    }.joined(separator: "; ")
  }

  @ViewBuilder
  private var pieRing: some View {
    let diameter: CGFloat = 160
    let radius = diameter / 2

    return ZStack {
      ForEach(Array(segmentAngles.enumerated()), id: \.offset) { index, angles in
        PieSlice(
          startAngle: angles.start,
          endAngle: angles.end
        )
        .fill(segments[index].color)
      }

      Circle()
        .fill(Color(.systemBackground))
        .frame(width: radius, height: radius)

      if total > 0 {
        VStack(spacing: 2) {
          Text("\(total)")
            .font(.title2.bold())
            .foregroundStyle(Color.darkSlate)
          Text("Total")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }
    }
    .frame(width: diameter, height: diameter)
  }

  @ViewBuilder
  private var legendView: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(segments) { segment in
        HStack(spacing: 8) {
          Circle()
            .fill(segment.color)
            .frame(width: 10, height: 10)

          Text(segment.label)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .lineLimit(1)

          Spacer()

          Text("\(segment.value)")
            .font(.caption.bold())
            .foregroundStyle(Color.darkSlate)
        }
      }
    }
  }

  @ViewBuilder
  private var emptyState: some View {
    ChartEmptyStateView(iconName: "chart.pie", message: String(localized: "No data available"))
  }

  private var segmentAngles: [(start: Angle, end: Angle)] {
    guard total > 0 else { return [] }
    var angles: [(start: Angle, end: Angle)] = []
    var currentAngle = Angle.degrees(-90)
    for segment in segments {
      let segmentAngle = Angle.degrees(Double(segment.value) / Double(total) * 360)
      angles.append((start: currentAngle, end: currentAngle + segmentAngle))
      currentAngle += segmentAngle
    }
    return angles
  }
}

private struct PieSlice: Shape {
  let startAngle: Angle
  let endAngle: Angle

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    var path = Path()
    path.move(to: center)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: startAngle,
      endAngle: endAngle,
      clockwise: false
    )
    path.closeSubpath()
    return path
  }
}
