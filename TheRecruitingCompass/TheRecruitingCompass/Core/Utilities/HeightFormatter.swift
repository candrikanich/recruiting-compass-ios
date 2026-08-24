import Foundation

/// Formats an athlete's height (stored as total inches) as `feet'inches"` (e.g. 74 → `6'2"`).
/// Single source of truth shared by the public profile card and the recruiting packet.
enum HeightFormatter {
  /// Non-optional form. Callers that already guarantee a value use this.
  static func feetInches(_ inches: Int) -> String {
    let feet = inches / 12
    let remainder = inches % 12
    return "\(feet)'\(remainder)\""
  }

  /// Optional form. Returns nil for nil or non-positive input so callers can omit the field.
  static func feetInches(_ inches: Int?) -> String? {
    guard let inches, inches > 0 else { return nil }
    return feetInches(inches)
  }
}
