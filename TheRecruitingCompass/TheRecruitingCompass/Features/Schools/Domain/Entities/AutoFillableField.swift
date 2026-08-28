import Foundation

/// Fields that can be auto-filled from College Scorecard API or NCAA database
/// Used by SchoolFormState to track which fields were auto-populated
enum AutoFillableField: String, Sendable {
  case name
  case location
  case city
  case state
  case website
  case division
  case conference
}
