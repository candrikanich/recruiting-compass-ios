import SwiftUI

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
