import SwiftUI

struct SummaryCard: Identifiable, Equatable, Sendable {
  let id = UUID()
  let title: String
  let value: Int
  let iconName: String
  let color: Color
  let trend: String?

  var isPositiveTrend: Bool {
    guard let trend else { return false }
    return trend.hasPrefix("+")
  }

  var isNegativeTrend: Bool {
    guard let trend else { return false }
    return trend.hasPrefix("-")
  }
}
