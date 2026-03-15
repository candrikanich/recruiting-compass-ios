import Testing
@testable import TheRecruitingCompass

@Suite("NotificationDestinationParser")
struct NotificationDestinationParserTests {

    // MARK: - from AppNotification (entity type)

    @Test func coachEntityReturnsCoachDetail() {
        let n = makeNotification(entityType: "coach", relatedCoachId: "c1")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "c1"))
    }

    @Test func schoolEntityReturnsSchoolDetail() {
        let n = makeNotification(entityType: "school", relatedSchoolId: "s1")
        #expect(NotificationDestinationParser.destination(from: n) == .schoolDetail(id: "s1"))
    }

    @Test func offerEntityReturnsOfferDetail() {
        let n = makeNotification(entityType: "offer", relatedOfferId: "o1")
        #expect(NotificationDestinationParser.destination(from: n) == .offerDetail(id: "o1"))
    }

    @Test func eventEntityReturnsEventDetail() {
        let n = makeNotification(entityType: "event", relatedEventId: "e1")
        #expect(NotificationDestinationParser.destination(from: n) == .eventDetail(id: "e1"))
    }

    @Test func interactionEntityReturnsInteractionDetail() {
        let n = makeNotification(entityType: "interaction", entityId: "i1")
        #expect(NotificationDestinationParser.destination(from: n) == .interactionDetail(id: "i1"))
    }

    @Test func interactionEntityWithNoFallbackIdReturnsNil() {
        let n = makeNotification(entityType: "interaction", entityId: nil)
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    @Test func coachFallsBackToEntityId() {
        let n = makeNotification(entityType: "coach", entityId: "fallback")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "fallback"))
    }

    @Test func unknownEntityTypeReturnsNil() {
        let n = makeNotification(entityType: "widget", entityId: "x")
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    @Test func noEntityTypeReturnsNil() {
        let n = makeNotification(entityType: nil)
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    // MARK: - from AppNotification (actionUrl)

    @Test func coachHighlightUrlReturnsCoachDetail() {
        let n = makeNotification(actionUrl: "/coaches?highlight=c42")
        #expect(NotificationDestinationParser.destination(from: n) == .coachDetail(id: "c42"))
    }

    @Test func schoolPathUrlReturnsSchoolDetail() {
        let n = makeNotification(actionUrl: "/schools/s99")
        #expect(NotificationDestinationParser.destination(from: n) == .schoolDetail(id: "s99"))
    }

    @Test func offerHighlightUrlReturnsOfferDetail() {
        let n = makeNotification(actionUrl: "/offers?highlight=o7")
        #expect(NotificationDestinationParser.destination(from: n) == .offerDetail(id: "o7"))
    }

    @Test func eventPathUrlReturnsEventDetail() {
        let n = makeNotification(actionUrl: "/events/ev3")
        #expect(NotificationDestinationParser.destination(from: n) == .eventDetail(id: "ev3"))
    }

    @Test func unknownUrlReturnsNil() {
        let n = makeNotification(actionUrl: "/dashboard")
        #expect(NotificationDestinationParser.destination(from: n) == nil)
    }

    // MARK: - fromPayload (APNs push)

    @Test func payloadCoachTypeReturnsCoachDetail() {
        let p: [AnyHashable: Any] = ["related_entity_type": "coach", "related_entity_id": "c5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == .coachDetail(id: "c5"))
    }

    @Test func payloadSchoolTypeReturnsSchoolDetail() {
        let p: [AnyHashable: Any] = ["related_entity_type": "school", "related_entity_id": "s5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == .schoolDetail(id: "s5"))
    }

    @Test func payloadMissingTypeReturnsNil() {
        let p: [AnyHashable: Any] = ["related_entity_id": "c5"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == nil)
    }

    @Test func payloadMissingIdReturnsNil() {
        let p: [AnyHashable: Any] = ["related_entity_type": "coach"]
        #expect(NotificationDestinationParser.destination(fromPayload: p) == nil)
    }

    // MARK: - Helpers

    private func makeNotification(
        entityType: String? = nil,
        entityId: String? = nil,
        relatedCoachId: String? = nil,
        relatedSchoolId: String? = nil,
        relatedOfferId: String? = nil,
        relatedEventId: String? = nil,
        actionUrl: String? = nil
    ) -> AppNotification {
        AppNotification(
            id: "test-id", userId: "user-1", type: .followUpReminder,
            title: "Test", message: "Body", priority: .normal,
            readAt: nil, scheduledFor: "2026-03-15T00:00:00Z",
            sentAt: nil, emailSent: nil, emailSentAt: nil,
            actionUrl: actionUrl,
            relatedEntityType: entityType,
            relatedEntityId: entityId,
            relatedSchoolId: relatedSchoolId,
            relatedCoachId: relatedCoachId,
            relatedOfferId: relatedOfferId,
            relatedEventId: relatedEventId,
            createdAt: nil, updatedAt: nil
        )
    }
}
