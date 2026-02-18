import Foundation

struct DocumentStatistics: Sendable {
  let total: Int
  let shared: Int
  let mostCommonType: String
  /// Phase 5 implementation - placeholder until storage aggregation exists
  let totalStorageMB: Double
}
