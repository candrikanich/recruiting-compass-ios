import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationGuardrailTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func vm(_ stub: GuardStubMessages, guardian: MockGuardianService? = nil) -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: GuardStubTemplates(),
      athleteMessagesService: stub,
      guardianService: guardian ?? MockGuardianService())
    v.configureContext(loggedBy: "u1", familyUnitId: "f1", athleteUserId: "a1", accessToken: "tok")
    return v
  }

  // MARK: - Guardian-linked-signup lock (COPPA-adjacent)

  func test_guardianPending_hardBlocksBeforeOtherChecks() async {
    let guardian = MockGuardianService()
    guardian.mockStatus = GuardianStatus(pending: true, guardianEmailMasked: "j***@x.com", expiresAt: nil, status: "pending")
    // Would otherwise pass cleanly — proves the guardian check runs first.
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 0)), guardian: guardian)

    let ok = await v.evaluateGuardrails(.email)

    XCTAssertFalse(ok)
    XCTAssertNotNil(v.sendWarning)
  }

  func test_guardianConfirmed_doesNotBlock() async {
    let guardian = MockGuardianService()
    guardian.mockStatus = GuardianStatus(pending: false, guardianEmailMasked: nil, expiresAt: nil, status: "claimed")
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 0)), guardian: guardian)

    let ok = await v.evaluateGuardrails(.email)

    XCTAssertTrue(ok)
  }

  func test_guardianStatusCheckThrows_failsOpen() async {
    let guardian = MockGuardianService()
    guardian.shouldThrowFetchStatusError = true
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 0)), guardian: guardian)

    let ok = await v.evaluateGuardrails(.email)

    XCTAssertTrue(ok, "A status-check failure must never block a legit send")
  }

  func test_programNoteReused_hardBlocks() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: true, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 0)))
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertFalse(ok)
    XCTAssertNotNil(v.sendWarning)
  }

  func test_recentContact_armsThenProceeds() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: 2, recentContact: true, messageCountToSchool: 1)))
    let first = await v.evaluateGuardrails(.email)
    XCTAssertFalse(first, "first tap arms + warns")
    XCTAssertNotNil(v.sendWarning)
    let second = await v.evaluateGuardrails(.email)
    XCTAssertTrue(second, "second tap proceeds")
  }

  func test_checkThrows_failsOpen() async {
    let v = vm(GuardStubMessages(result: nil, error: AthleteMessagesError.server(500)))
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertTrue(ok)
  }

  func test_noAthlete_doesNotBlock() async {
    let v = QuickCommunicationViewModel(coach: coach(), templatesService: GuardStubTemplates(),
      athleteMessagesService: GuardStubMessages(result: .init(
        programNoteReused: true, daysSinceLastContact: nil, recentContact: false, messageCountToSchool: 9)))
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertTrue(ok)
  }

  func test_selectTemplateResetsWarnAndArm() async {
    let v = vm(GuardStubMessages(result: .init(
      programNoteReused: false, daysSinceLastContact: 2, recentContact: true, messageCountToSchool: 1)))
    _ = await v.evaluateGuardrails(.email)   // arms
    v.selectTemplate(nil)
    XCTAssertNil(v.sendWarning)
    let ok = await v.evaluateGuardrails(.email)
    XCTAssertFalse(ok, "arm was reset → warns again, not proceed")
  }
}

private struct GuardStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct GuardStubMessages: AthleteMessagesServicing {
  var result: SendCheckResult?
  var error: Error?
  func checkSend(_ input: SendCheckInput, accessToken: String?) async throws -> SendCheckResult {
    if let error { throw error }
    return result!
  }
  func logSend(_ input: LogMessageInput, accessToken: String?) async throws {}
}
