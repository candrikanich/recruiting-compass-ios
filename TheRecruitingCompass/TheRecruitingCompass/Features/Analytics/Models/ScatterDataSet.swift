import Foundation

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
