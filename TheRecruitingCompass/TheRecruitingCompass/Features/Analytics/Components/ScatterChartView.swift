import SwiftUI

struct ScatterChartView: View {
  let dataSet: ScatterDataSet
  let title: String

  @State private var selectedPoint: ScatterDataPoint?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var xRange: ClosedRange<Double> {
    guard let minX = dataSet.points.map(\.x).min(),
          let maxX = dataSet.points.map(\.x).max() else {
      return 0...100
    }
    let padding = (maxX - minX) * 0.1
    return (minX - padding)...(maxX + padding)
  }

  private var yRange: ClosedRange<Double> {
    guard let minY = dataSet.points.map(\.y).min(),
          let maxY = dataSet.points.map(\.y).max() else {
      return 0...100
    }
    let padding = (maxY - minY) * 0.1
    return (minY - padding)...(maxY + padding)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
          .foregroundStyle(Color.darkSlate)
          .accessibilityAddTraits(.isHeader)

        Text(dataSet.label)
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      }

      if dataSet.points.isEmpty {
        emptyState
      } else {
        ZStack {
          chartArea
          pointsOverlay
        }
        .frame(height: 300)
        .padding(.bottom, 24)

        axisLabels
      }

      if let selected = selectedPoint {
        selectedPointInfo(selected)
      }
    }
    .chartCard()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(scatterAccessibilityLabel)
    .accessibilityValue(scatterAccessibilityValue)
  }

  private var scatterAccessibilityLabel: String {
    if dataSet.points.isEmpty {
      return "\(title) scatter plot. No correlation data."
    }
    return "\(title) scatter plot. \(dataSet.label). \(dataSet.points.count) data points. \(dataSet.xAxisLabel) versus \(dataSet.yAxisLabel)."
  }

  private var scatterAccessibilityValue: String {
    guard !dataSet.points.isEmpty else { return "" }
    let xValues = dataSet.points.map(\.x)
    let yValues = dataSet.points.map(\.y)
    guard let minX = xValues.min(), let maxX = xValues.max(),
          let minY = yValues.min(), let maxY = yValues.max() else { return "" }
    return "\(dataSet.xAxisLabel) ranges from \(minX.formatted(.number.precision(.fractionLength(0)))) to \(maxX.formatted(.number.precision(.fractionLength(0)))). \(dataSet.yAxisLabel) ranges from \(minY.formatted(.number.precision(.fractionLength(0)))) to \(maxY.formatted(.number.precision(.fractionLength(0))))."
  }

  private var chartArea: some View {
    GeometryReader { geometry in
      let gridLines = 5

      ForEach(0..<gridLines, id: \.self) { i in
        let yPos = geometry.size.height * CGFloat(i) / CGFloat(gridLines - 1)
        Path { path in
          path.move(to: CGPoint(x: 0, y: yPos))
          path.addLine(to: CGPoint(x: geometry.size.width, y: yPos))
        }
        .stroke(Color.borderGray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
      }
    }
  }

  private var pointsOverlay: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height

      ForEach(dataSet.points) { point in
        let xPos = normalizeX(point.x) * width
        let yPos = height - normalizeY(point.y) * height

        Circle()
          .fill(point.color)
          .frame(width: 12, height: 12)
          .shadow(color: point.color.opacity(0.3), radius: 2)
          .position(x: xPos, y: yPos)
          .onTapGesture {
            if reduceMotion {
              selectedPoint = selectedPoint?.id == point.id ? nil : point
            } else {
              withAnimation(.easeInOut(duration: 0.2)) {
                selectedPoint = selectedPoint?.id == point.id ? nil : point
              }
            }
          }
          .accessibilityHidden(true)
      }
    }
  }

  private var axisLabels: some View {
    HStack {
      Spacer()
      Text(dataSet.xAxisLabel)
        .font(.caption)
        .foregroundStyle(Color.secondaryText)
      Spacer()
    }
  }

  private func selectedPointInfo(_ point: ScatterDataPoint) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(point.label)
          .font(.subheadline.bold())
          .foregroundStyle(Color.darkSlate)
        Text("\(dataSet.xAxisLabel): \(point.x.formatted(.number.precision(.fractionLength(1))))")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
        Text("\(dataSet.yAxisLabel): \(point.y.formatted(.number.precision(.fractionLength(1))))")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
      }
      Spacer()
      Button {
        selectedPoint = nil
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(Color.iconGray)
      }
      .accessibilityLabel("Dismiss data point details")
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .padding(12)
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(point.label), \(dataSet.xAxisLabel): \(point.x.formatted(.number.precision(.fractionLength(1)))), \(dataSet.yAxisLabel): \(point.y.formatted(.number.precision(.fractionLength(1))))")
  }

  private var emptyState: some View {
    ChartEmptyStateView(iconName: "chart.dots.scatter", message: "No correlation data")
  }

  private func normalizeX(_ value: Double) -> CGFloat {
    let range = xRange.upperBound - xRange.lowerBound
    guard range > 0 else { return 0.5 }
    return CGFloat((value - xRange.lowerBound) / range)
  }

  private func normalizeY(_ value: Double) -> CGFloat {
    let range = yRange.upperBound - yRange.lowerBound
    guard range > 0 else { return 0.5 }
    return CGFloat((value - yRange.lowerBound) / range)
  }
}
