import Foundation

enum SortOption: String, CaseIterable {
  case dateDesc = "Date (Newest First)"
  case dateAsc = "Date (Oldest First)"
  case name = "Name"
  case type = "Type"
}
