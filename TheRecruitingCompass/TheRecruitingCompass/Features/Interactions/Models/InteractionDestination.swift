import Foundation

enum InteractionDestination: Hashable, Sendable {
  case add
  case addWithSchool(String)  // Pre-filled school ID
  case detail(String)         // Interaction ID
}
