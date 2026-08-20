import XCTest
@testable import TheRecruitingCompass

/// Item 1d — send-time recruiting-questionnaire prompt. Mirrors the web amber-banner gate
/// natively: prompt when a template uses `{{questionnaireNote}}` and the school's flag is
/// still false, persist on confirm (reusing the school-detail path), send bare on skip.
@MainActor
final class QuickCommunicationQuestionnaireTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com",
          phone: nil, position: "Head Coach", schoolId: "s1",
          createdAt: "", updatedAt: "")
  }

  private func template(body: String) -> CommunicationTemplate {
    CommunicationTemplate(id: "t1", userId: "", name: "Intro", type: .email,
                          body: body, variables: nil, createdAt: "", updatedAt: "")
  }

  /// Registry carrying the computed `questionnaireNote` def, so the resolver renders the
  /// completion sentence when the school flag is set (parity with the seeded web variable).
  private func registry() -> [TemplateVariableDef] {
    [TemplateVariableDef(key: "questionnaireNote", label: "", category: "program",
                         sourceType: .computed, isRequiredDefault: false)]
  }

  private func makeVM(questionnaireCompleted: Bool,
                      schools: MockSchoolsService = MockSchoolsService())
    -> (QuickCommunicationViewModel, MockSchoolsService) {
    let ctx = TablesStubContext(schools: ["questionnaire_completed": questionnaireCompleted ? "true" : "false"])
    let vm = QuickCommunicationViewModel(
      coach: coach(), schoolName: "Duke University",
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: ctx,
      schoolsService: schools)
    return (vm, schools)
  }

  private let bodyWithToken = "Coach Smith,\n{{questionnaireNote}}I'd welcome any feedback."

  func test_prompts_whenTokenPresentAndIncomplete() async {
    let (vm, _) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertTrue(vm.shouldPromptQuestionnaire)
  }

  func test_noPrompt_whenAlreadyComplete() async {
    let (vm, _) = makeVM(questionnaireCompleted: true)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertFalse(vm.shouldPromptQuestionnaire)
  }

  func test_noPrompt_whenTokenAbsent() async {
    let (vm, _) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: "Coach Smith, thanks for your time."))
    XCTAssertFalse(vm.shouldPromptQuestionnaire)
  }

  func test_confirm_persistsFlagAndClearsPrompt() async {
    let (vm, schools) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertTrue(vm.shouldPromptQuestionnaire)

    await vm.confirmQuestionnaireCompleted()

    XCTAssertEqual(schools.updateQuestionnaireCompletedCallCount, 1)
    XCTAssertEqual(schools.lastQuestionnaireCompleted, true)
    XCTAssertFalse(vm.shouldPromptQuestionnaire, "prompt must not re-fire after confirm")
  }

  func test_skip_clearsPromptWithoutPersisting() async {
    let (vm, schools) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))

    vm.skipQuestionnairePrompt()

    XCTAssertEqual(schools.updateQuestionnaireCompletedCallCount, 0)
    XCTAssertFalse(vm.shouldPromptQuestionnaire)
  }

  func test_selectTemplate_resetsPromptState() async {
    let (vm, _) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    vm.skipQuestionnairePrompt()
    XCTAssertFalse(vm.shouldPromptQuestionnaire)

    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertTrue(vm.shouldPromptQuestionnaire, "a fresh template re-arms the prompt")
  }

  func test_completeSchool_rendersCompletionSentence() async {
    let (vm, _) = makeVM(questionnaireCompleted: true)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertTrue(vm.cleanBody.contains("I've completed your recruiting questionnaire."),
                  "completion sentence should render when the flag is set")
  }

  func test_incompleteSchool_dropsCompletionSentence() async {
    let (vm, _) = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: bodyWithToken))
    XCTAssertFalse(vm.cleanBody.contains("I've completed your recruiting questionnaire."),
                   "optional token stripped when the flag is unset")
    XCTAssertTrue(vm.cleanBody.contains("I'd welcome any feedback."))
  }
}

// MARK: - Stubs

private struct StubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}

private struct StubRegistry: TemplateVariablesServicing {
  let defs: [TemplateVariableDef]
  func fetchRegistry() async throws -> [TemplateVariableDef] { defs }
}

/// Context stub that injects a `schools` table row, so `questionnaire_completed` drives
/// both the prompt gate and the `questionnaireNote` computed scalar.
private struct TablesStubContext: TemplateContextProviding {
  let schools: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: ["schools": schools], prefs: [:], authored: authored,
                    derived: [:], metrics: [], events: [], now: now)
  }
}
