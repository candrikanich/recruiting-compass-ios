import Foundation

enum CoachDestination: Hashable {
  case detail(String)           // Coach ID
  case add
  case filteredBySchool(String) // School ID
}
