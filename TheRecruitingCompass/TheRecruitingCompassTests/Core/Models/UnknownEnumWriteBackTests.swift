import XCTest
@testable import TheRecruitingCompass

/// `.unknown` is a decode-only fallback: it must never reach the server, so the key is omitted
/// and the server keeps its real value.
@MainActor
final class UnknownEnumWriteBackTests: XCTestCase {
  nonisolated deinit {}

  private func keys<T: Encodable>(_ value: T) throws -> Set<String> {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return Set(object?.keys.map { $0 } ?? [])
  }

  func testServerValue_nilForUnknown_rawValueOtherwise() {
    XCTAssertNil(Direction.unknown.serverValue)
    XCTAssertNil(Sentiment.unknown.serverValue)
    XCTAssertNil(TaskStatus.unknown.serverValue)
    XCTAssertNil(DeadlineCategory.unknown.serverValue)
    XCTAssertNil(TimelinePhase.unknown.serverValue)
    XCTAssertNil(StatusLabel.unknown.serverValue)
    XCTAssertNil(Suggestion.UrgencyLevel.unknown.serverValue)
    XCTAssertNil(CommitmentStatus.unknown.serverValue)
    XCTAssertEqual(Sentiment.veryPositive.serverValue, "very_positive")
    XCTAssertEqual(Direction.inbound.serverValue, "inbound")
  }

  func testCreateInteractionRequest_omitsUnknownSentiment() throws {
    let request = CreateInteractionRequest(
      userId: "u", eventId: "e", coachId: nil, type: "email",
      direction: Direction.inbound.serverValue, sentiment: Sentiment.unknown.serverValue, notes: nil)
    let encoded = try keys(request)
    XCTAssertFalse(encoded.contains("sentiment"))
    XCTAssertTrue(encoded.contains("direction"))
  }

  func testCreateInteractionRequest_omitsUnknownDirection() throws {
    let request = CreateInteractionRequest(
      userId: "u", eventId: "e", coachId: nil, type: "email",
      direction: Direction.unknown.serverValue, sentiment: Sentiment.neutral.serverValue, notes: nil)
    let encoded = try keys(request)
    XCTAssertFalse(encoded.contains("direction"))
    XCTAssertTrue(encoded.contains("sentiment"))
  }

  func testInteractionCreateRequest_omitsUnknownSentiment() throws {
    let request = InteractionCreateRequest(
      schoolId: nil, coachId: nil, type: .email, direction: .outbound, occurredAt: .now,
      subject: nil, content: nil, sentiment: .unknown, loggedBy: "u", familyUnitId: "f")
    XCTAssertFalse(try keys(request).contains("sentiment"))
  }

  func testDeadlineUpdatePayload_omitsUnknownCategory() throws {
    let payload = DeadlineUpdatePayload(label: "L", deadlineDate: "2026-01-01", category: nil, schoolId: nil)
    XCTAssertFalse(try keys(payload).contains("category"))
    let known = DeadlineUpdatePayload(
      label: "L", deadlineDate: "2026-01-01", category: DeadlineCategory.visit.serverValue, schoolId: nil)
    XCTAssertTrue(try keys(known).contains("category"))
  }

  func testDeadlineUpdatePayloadFromRequest_omitsUnknownCategory() throws {
    let request = DeadlineUpdateRequest(label: "L", deadlineDate: "2026-01-01", category: .unknown, schoolId: nil)
    XCTAssertFalse(try keys(DeadlineUpdatePayload(request)).contains("category"))
  }

  func testAthleteTaskUpsert_omitsUnknownStatus() throws {
    let payload = AthleteTaskUpsert(taskId: "t", athleteId: "a", status: .unknown, completedAt: nil)
    XCTAssertFalse(try keys(payload).contains("status"))
    let known = AthleteTaskUpsert(taskId: "t", athleteId: "a", status: .completed, completedAt: nil)
    XCTAssertTrue(try keys(known).contains("status"))
  }

  func testUpdateProfilePayload_omitsUnknownCommitmentStatus() throws {
    XCTAssertFalse(try keys(UpdateProfilePayload(commitmentStatus: .unknown)).contains("commitment_status"))
    XCTAssertTrue(try keys(UpdateProfilePayload(commitmentStatus: .committed)).contains("commitment_status"))
  }
}
