import Foundation

enum NotificationDestination: Hashable, Sendable {
  case coachDetail(id: String)
  case schoolDetail(id: String)
  case interactionDetail(id: String)
  case offerDetail(id: String)
  case eventDetail(id: String)
}
