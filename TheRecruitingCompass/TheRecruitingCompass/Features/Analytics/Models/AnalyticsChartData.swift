import Foundation
import SwiftUI

protocol ChartLabelValue {
  var label: String { get }
  var value: Int { get }
}

struct PieChartSegment: Identifiable, Equatable, Sendable, ChartLabelValue {
  let id: UUID
  let label: String
  let value: Int
  let color: Color

  init(id: UUID = UUID(), label: String, value: Int, color: Color) {
    self.id = id
    self.label = label
    self.value = value
    self.color = color
  }

  var percentage: Double {
    Double(value)
  }
}

struct FunnelStage: Identifiable, Equatable, Sendable, ChartLabelValue {
  let id: UUID
  let label: String
  let value: Int
  let color: Color

  init(id: UUID = UUID(), label: String, value: Int, color: Color) {
    self.id = id
    self.label = label
    self.value = value
    self.color = color
  }
}

struct ScatterDataPoint: Identifiable, Equatable, Sendable {
  let id: UUID
  let x: Double
  let y: Double
  let label: String
  let color: Color

  init(id: UUID = UUID(), x: Double, y: Double, label: String, color: Color = .accentBlue) {
    self.id = id
    self.x = x
    self.y = y
    self.label = label
    self.color = color
  }
}

struct ScatterDataSet: Equatable, Sendable {
  let label: String
  let points: [ScatterDataPoint]
  let xAxisLabel: String
  let yAxisLabel: String

  init(
    label: String,
    points: [ScatterDataPoint],
    xAxisLabel: String = "X",
    yAxisLabel: String = "Y"
  ) {
    self.label = label
    self.points = points
    self.xAxisLabel = xAxisLabel
    self.yAxisLabel = yAxisLabel
  }
}
