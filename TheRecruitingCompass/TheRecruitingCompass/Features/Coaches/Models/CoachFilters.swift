import Foundation

struct CoachFilters: Equatable, Sendable {
  var searchText: String = ""
  var role: CoachRole?
  var lastContactDays: Int?
  var responsivenessLevel: ResponsivenessLevel?
  var sortBy: CoachSortOption = .name

  var hasActiveFilters: Bool {
    role != nil || lastContactDays != nil || responsivenessLevel != nil
  }

  var activeFilterCount: Int {
    var count = 0
    if role != nil { count += 1 }
    if lastContactDays != nil { count += 1 }
    if responsivenessLevel != nil { count += 1 }
    return count
  }
}

enum ResponsivenessLevel: String, CaseIterable, Sendable {
  case high
  case medium
  case low

  var displayName: String {
    switch self {
    case .high: return "High (75-100%)"
    case .medium: return "Medium (50-74%)"
    case .low: return "Low (0-49%)"
    }
  }

  var range: ClosedRange<Double> {
    switch self {
    case .high: return 75...100
    case .medium: return 50...74
    case .low: return 0...49
    }
  }

  func matches(score: Double) -> Bool {
    range.contains(score)
  }
}

enum CoachSortOption: String, CaseIterable, Sendable {
  case name
  case school
  case lastContacted
  case responsiveness
  case role

  var displayName: String {
    switch self {
    case .name: return "Name"
    case .school: return "School"
    case .lastContacted: return "Last Contacted"
    case .responsiveness: return "Responsiveness"
    case .role: return "Role"
    }
  }
}

enum LastContactOption: Int, CaseIterable, Sendable {
  case sevenDays = 7
  case thirtyDays = 30
  case sixtyDays = 60
  case ninetyDays = 90

  var displayName: String {
    switch self {
    case .sevenDays: return "Last 7 days"
    case .thirtyDays: return "Last 30 days"
    case .sixtyDays: return "Last 60 days"
    case .ninetyDays: return "Last 90 days"
    }
  }
}
