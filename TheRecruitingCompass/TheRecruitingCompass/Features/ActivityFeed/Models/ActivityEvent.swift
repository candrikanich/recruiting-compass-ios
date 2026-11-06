import Foundation

struct ActivityEvent: Identifiable, Sendable, Codable {
  let id: String
  let type: ActivityEventType
  let timestamp: Date
  let title: String
  let description: String
  let icon: String
  let entityType: String?
  let entityId: String?
  let entityName: String?
  let isClickable: Bool
  let clickUrl: String?
  /// Who did it; the view model resolves this to "You" / a member name.
  var actorUserId: String?
}
