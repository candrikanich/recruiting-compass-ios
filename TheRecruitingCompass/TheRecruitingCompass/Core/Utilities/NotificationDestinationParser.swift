import Foundation

enum NotificationDestinationParser {

    static func destination(from notification: AppNotification) -> NotificationDestination? {
        if let actionUrl = notification.actionUrl {
            return destination(fromActionUrl: actionUrl)
        }
        guard let entityType = notification.relatedEntityType else { return nil }
        return destination(
            entityType: entityType,
            primaryId: primaryId(for: entityType, notification: notification),
            fallbackId: notification.relatedEntityId
        )
    }

    static func destination(fromPayload payload: [AnyHashable: Any]) -> NotificationDestination? {
        guard let entityType = payload["related_entity_type"] as? String,
              let entityId   = payload["related_entity_id"]   as? String else { return nil }
        return destination(entityType: entityType, primaryId: entityId, fallbackId: nil)
    }

    // MARK: - Private

    private static func primaryId(for entityType: String, notification: AppNotification) -> String? {
        switch entityType {
        case "coach":       return notification.relatedCoachId
        case "school":      return notification.relatedSchoolId
        case "offer":       return notification.relatedOfferId
        case "event":       return notification.relatedEventId
        default:            return nil
        }
    }

    private static func destination(
        entityType: String,
        primaryId: String?,
        fallbackId: String?
    ) -> NotificationDestination? {
        guard let id = primaryId ?? fallbackId else { return nil }
        switch entityType {
        case "coach":       return .coachDetail(id: id)
        case "school":      return .schoolDetail(id: id)
        case "offer":       return .offerDetail(id: id)
        case "event":       return .eventDetail(id: id)
        case "interaction": return .interactionDetail(id: id)
        default:            return nil
        }
    }

    private static func destination(fromActionUrl url: String) -> NotificationDestination? {
        if url.contains("/coaches") {
            return extractId(from: url, pattern: "highlight=").map { .coachDetail(id: $0) }
        } else if url.contains("/schools/") {
            return lastPathComponent(of: url).map { .schoolDetail(id: $0) }
        } else if url.contains("/offers") {
            return extractId(from: url, pattern: "highlight=").map { .offerDetail(id: $0) }
        } else if url.contains("/events/") {
            return lastPathComponent(of: url).map { .eventDetail(id: $0) }
        } else if url.contains("/interactions/") {
            return lastPathComponent(of: url).map { .interactionDetail(id: $0) }
        }
        return nil
    }

    private static func extractId(from url: String, pattern: String) -> String? {
        guard let range = url.range(of: pattern) else { return nil }
        let after = url[range.upperBound...]
        return after.components(separatedBy: "&").first.map { String($0) }
    }

    private static func lastPathComponent(of url: String) -> String? {
        let component = url.components(separatedBy: "/").last
        return component.flatMap { $0.isEmpty ? nil : $0 }
    }
}
