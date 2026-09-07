import Foundation
import Testing
@testable import TheRecruitingCompass

@Suite("InboundEmailDraft")
struct InboundEmailDraftTests {

  @Test func decodesSnakeCaseWireShape() throws {
    let json = """
    {
      "id": "draft-1",
      "family_unit_id": "fam-1",
      "raw_email_id": "raw-1",
      "matched_coach_id": null,
      "matched_school_id": null,
      "sender_name": "Coach Smith",
      "sender_email": "coach@school.edu",
      "subject": "Great game!",
      "body_text": "Line one\\nLine two",
      "occurred_at": "2026-09-01T12:00:00.000Z",
      "status": "pending",
      "confirmed_interaction_id": null,
      "created_at": "2026-09-01T12:05:00.000Z"
    }
    """.data(using: .utf8)!

    let draft = try JSONDecoder().decode(InboundEmailDraft.self, from: json)

    #expect(draft.id == "draft-1")
    #expect(draft.familyUnitId == "fam-1")
    #expect(draft.senderEmail == "coach@school.edu")
    #expect(draft.status == "pending")
    #expect(draft.matchedSchoolId == nil)
    #expect(draft.bodyText == "Line one\nLine two")
  }

  @Test func displaySenderNameFallsBackWhenNil() throws {
    let draft = InboundEmailDraft(
      id: "d1", familyUnitId: "f1", rawEmailId: nil, matchedCoachId: nil, matchedSchoolId: nil,
      senderName: nil, senderEmail: "x@y.com", subject: nil, bodyText: nil,
      occurredAt: "2026-09-01T00:00:00Z", status: "pending", confirmedInteractionId: nil,
      createdAt: "2026-09-01T00:00:00Z"
    )
    #expect(draft.displaySenderName == "Unknown sender")
  }

  @Test func decodesUnrecognizedStatusGracefully() throws {
    // status is plain Postgres text, not an enum — a future value must not fail decode.
    let json = """
    {
      "id": "d1", "family_unit_id": "f1", "raw_email_id": null,
      "matched_coach_id": null, "matched_school_id": null,
      "sender_name": null, "sender_email": null, "subject": null, "body_text": null,
      "occurred_at": "2026-09-01T00:00:00Z", "status": "some-future-status",
      "confirmed_interaction_id": null, "created_at": "2026-09-01T00:00:00Z"
    }
    """.data(using: .utf8)!

    let draft = try JSONDecoder().decode(InboundEmailDraft.self, from: json)
    #expect(draft.status == "some-future-status")
  }
}
