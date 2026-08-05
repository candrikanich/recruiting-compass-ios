import Foundation

struct ActivityDestination: Hashable {
  let eventType: ActivityEventType
  let entityId: String?
  let clickUrl: String?

  init(event: ActivityEvent) {
    self.eventType = event.type
    self.entityId = event.entityId
    self.clickUrl = event.clickUrl
  }
}
