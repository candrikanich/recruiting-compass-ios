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

  // MARK: - #311 / #314 follow-ups

  func testServerValue_nilForUnknown_forRemainingWrittenEnums() {
    XCTAssertNil(InteractionType.unknown.serverValue)
    XCTAssertNil(OfferStatus.unknown.serverValue)
    XCTAssertNil(OfferType.unknown.serverValue)
    XCTAssertNil(TemplateType.unknown.serverValue)
    XCTAssertNil(VideoLinkPlatform.unknown.serverValue)
    XCTAssertNil(SchoolStatus.unknown.serverValue)
    XCTAssertEqual(InteractionType.phoneCall.serverValue, "phone_call")
    XCTAssertEqual(OfferType.fullRide.serverValue, "full_ride")
    XCTAssertEqual(OfferStatus.pending.serverValue, "pending")
    XCTAssertEqual(TemplateType.social.serverValue, "social")
    XCTAssertEqual(VideoLinkPlatform.hudl.serverValue, "hudl")
  }

  func testOfferUpdateRequest_omitsUnknownTypeAndStatus_keepsKnown() throws {
    var edit = OfferEditData()
    edit.offerType = .unknown
    edit.status = .unknown
    let unknown = try keys(OfferUpdateRequest(from: edit))
    XCTAssertFalse(unknown.contains("offer_type"))
    XCTAssertFalse(unknown.contains("status"))
    edit.offerType = .fullRide
    edit.status = .accepted
    let known = try keys(OfferUpdateRequest(from: edit))
    XCTAssertTrue(known.contains("offer_type"))
    XCTAssertTrue(known.contains("status"))
  }

  func testOfferCreateRequest_omitsUnknownTypeAndStatus_keepsKnown() throws {
    var form = NewOfferFormState()
    form.schoolId = "s1"
    form.offerType = .unknown
    form.status = .unknown
    let unknown = try keys(OfferCreateRequest(userId: "u", form: form))
    XCTAssertFalse(unknown.contains("offer_type"))
    XCTAssertFalse(unknown.contains("status"))
    form.offerType = .partial
    form.status = .declined
    let known = try keys(OfferCreateRequest(userId: "u", form: form))
    XCTAssertTrue(known.contains("offer_type"))
    XCTAssertTrue(known.contains("status"))
  }

  func testInteractionCreateRequest_omitsUnknownType() throws {
    let unknown = InteractionCreateRequest(
      schoolId: nil, coachId: nil, type: .unknown, direction: .outbound, occurredAt: .now,
      subject: nil, content: nil, sentiment: nil, loggedBy: "u", familyUnitId: "f")
    XCTAssertFalse(try keys(unknown).contains("type"))
    let known = InteractionCreateRequest(
      schoolId: nil, coachId: nil, type: .phoneCall, direction: .outbound, occurredAt: .now,
      subject: nil, content: nil, sentiment: nil, loggedBy: "u", familyUnitId: "f")
    XCTAssertTrue(try keys(known).contains("type"))
  }

  func testCreateInteractionRequest_omitsUnknownType() throws {
    let request = CreateInteractionRequest(
      userId: "u", eventId: "e", coachId: nil, type: InteractionType.unknown.serverValue,
      direction: nil, sentiment: nil, notes: nil)
    XCTAssertFalse(try keys(request).contains("type"))
  }

  func testInboundDraftConfirmRequest_omitsUnknownDirectionAndType() throws {
    let unknown = InboundDraftConfirmRequest(
      schoolId: nil, coachId: nil, type: .unknown, direction: .unknown,
      occurredAt: .now, subject: nil, content: nil)
    let unknownKeys = try keys(unknown)
    XCTAssertFalse(unknownKeys.contains("direction"))
    XCTAssertFalse(unknownKeys.contains("type"))
    XCTAssertTrue(unknownKeys.contains("coachId"), "cleared fields must still encode explicit null")
    let known = InboundDraftConfirmRequest(
      schoolId: nil, coachId: nil, type: .email, direction: .inbound,
      occurredAt: .now, subject: nil, content: nil)
    let knownKeys = try keys(known)
    XCTAssertTrue(knownKeys.contains("direction"))
    XCTAssertTrue(knownKeys.contains("type"))
  }

  func testTemplateUpdatePayload_omitsUnknownType() throws {
    var form = TemplateFormData()
    form.type = .unknown
    XCTAssertFalse(try keys(CommunicationTemplatesServiceImpl.updatePayload(from: form)).contains("type"))
    form.type = .email
    XCTAssertTrue(try keys(CommunicationTemplatesServiceImpl.updatePayload(from: form)).contains("type"))
  }

  func testVideoLinkUpdatePayload_omitsUnknownPlatform() throws {
    let unknown = VideoLinksServiceImpl.updatePayload(
      VideoLinkUpdateRequest(platform: .unknown, url: "u", title: nil, position: nil))
    XCTAssertFalse(try keys(unknown).contains("platform"))
    let known = VideoLinksServiceImpl.updatePayload(
      VideoLinkUpdateRequest(platform: .youtube, url: "u", title: nil, position: nil))
    XCTAssertTrue(try keys(known).contains("platform"))
  }

  func testSchoolStatusHistoryRow_omitsUnknownPreviousStatus() {
    let unknown = SchoolsRepositoryImpl.statusHistoryRow(
      schoolId: "s", previous: .unknown, new: .contacted, userId: "u", changedAt: "t")
    XCTAssertNil(unknown["previous_status"])
    XCTAssertEqual(unknown["new_status"], "contacted")
    let known = SchoolsRepositoryImpl.statusHistoryRow(
      schoolId: "s", previous: .researching, new: .contacted, userId: "u", changedAt: "t")
    XCTAssertEqual(known["previous_status"], "researching")
  }

  func testTimelinePhaseUnknown_hasNoGradeLevel() {
    XCTAssertNil(TimelinePhase.unknown.gradeLevel)
    XCTAssertEqual(TimelinePhase.senior.gradeLevel, 12)
    XCTAssertEqual(TimelinePhase.committed.gradeLevel, 12)
  }

  func testInteractionBreakdown_countsUnknownSentimentsAndTypes() {
    let result = AnalyticsServiceImpl.interactionBreakdown(rows: [
      (type: "email", sentiment: "positive"),
      (type: "carrier_pigeon", sentiment: "ecstatic"),
      (type: "carrier_pigeon", sentiment: nil)
    ])
    XCTAssertEqual(result.bySentiment.first { $0.label == Sentiment.unknown.displayName }?.value, 1)
    XCTAssertEqual(result.byType.first { $0.label == InteractionType.unknown.displayName }?.value, 2)
    XCTAssertEqual(result.bySentiment.first { $0.label == Sentiment.positive.displayName }?.value, 1)
  }
}
