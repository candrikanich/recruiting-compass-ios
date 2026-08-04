import SwiftUI

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
