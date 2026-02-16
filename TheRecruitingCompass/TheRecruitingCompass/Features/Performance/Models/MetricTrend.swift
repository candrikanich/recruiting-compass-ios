import Foundation

struct MetricTrend: Identifiable, Equatable {
  let id = UUID()
  let type: MetricType
  let values: [Double]
  let min: Double
  let max: Double
  let average: Double
  let unit: String
  let count: Int
  let trend: TrendDirection

  enum TrendDirection: String, Equatable {
    case improving
    case declining
    case stable

    var label: String {
      switch self {
      case .improving: return "Improving"
      case .declining: return "Declining"
      case .stable: return "Stable"
      }
    }

    var systemImage: String {
      switch self {
      case .improving: return "arrow.up.right"
      case .declining: return "arrow.down.right"
      case .stable: return "arrow.right"
      }
    }
  }

  static func == (lhs: MetricTrend, rhs: MetricTrend) -> Bool {
    lhs.type == rhs.type && lhs.count == rhs.count && lhs.trend == rhs.trend
  }
}
