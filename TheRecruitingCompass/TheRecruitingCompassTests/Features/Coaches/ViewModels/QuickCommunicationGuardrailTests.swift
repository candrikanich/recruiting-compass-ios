import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationGuardrailTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func vm(_ stub: GuardStubMessages) -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: GuardStubTemplates(),
      athleteMessagesService: stub)
    v.configureContext(loggedBy: "u1", familyUnitId: "f1", athleteUserId: "a1", accessToken: "tok")
    return v
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
