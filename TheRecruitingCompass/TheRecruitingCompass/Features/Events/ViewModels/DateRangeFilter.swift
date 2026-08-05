import Foundation

enum DateRangeFilter: String, CaseIterable {
  case all = "All Dates"
  case upcoming = "Upcoming"
  case past = "Past"
  case thisMonth = "This Month"
  case nextMonth = "Next Month"
}
