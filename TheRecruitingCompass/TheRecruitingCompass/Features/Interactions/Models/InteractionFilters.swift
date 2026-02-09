import Foundation

struct InteractionFilters: Sendable {
  var searchText: String = ""
  var type: InteractionType?
  var direction: Direction?
  var sentiment: Sentiment?
  var timePeriod: TimePeriod?
  var loggedBy: String?

  var hasActiveFilters: Bool {
    !searchText.isEmpty || type != nil || direction != nil ||
    sentiment != nil || timePeriod != nil || loggedBy != nil
  }

  var activeFilterCount: Int {
    var count = 0
    if !searchText.isEmpty { count += 1 }
    if type != nil { count += 1 }
    if direction != nil { count += 1 }
    if sentiment != nil { count += 1 }
    if timePeriod != nil { count += 1 }
    if loggedBy != nil { count += 1 }
    return count
  }
}
