import Foundation

enum CoachDestination: Hashable {
  case detail(String)           // Coach ID
  case add
  case addSchool
  case filteredBySchool(String) // School ID
}
