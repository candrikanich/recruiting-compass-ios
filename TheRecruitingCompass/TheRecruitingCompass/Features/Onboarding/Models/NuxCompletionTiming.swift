import Foundation

/// Shared 24h auto-hide window for NUX "100% complete" banners
/// (Getting Started checklist and Profile Completeness card).
enum NuxCompletionTiming {
  static let autoHideThresholdHours: Double = 24

  static func hasExpired(_ completedAt: Date, now: Date = Date()) -> Bool {
    now.timeIntervalSince(completedAt) >= autoHideThresholdHours * 3600
  }
}
