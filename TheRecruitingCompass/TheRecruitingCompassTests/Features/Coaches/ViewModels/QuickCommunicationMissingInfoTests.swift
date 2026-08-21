import XCTest
@testable import TheRecruitingCompass

/// Unified "Complete your info" step: `missingInfoFields` turns every UNRESOLVED thing the
/// current template references into one ordered list of row descriptors (missing-only), and
/// `hasMissingInfo` drives whether the step is inserted or auto-skipped before Preview.
@MainActor
final class QuickCommunicationMissingInfoTests: XCTestCase {
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

  /// Registry covering each collectible source kind: computed questionnaire, prefs-backed
  /// major (column), authored specificity + generic authored, computed metrics, and a
  /// column value that resolves from the injected `schools` row.
  private func registry() -> [TemplateVariableDef] {
    [
      TemplateVariableDef(key: "questionnaireNote", label: "", category: "program",
                          sourceType: .computed, isRequiredDefault: false),
      TemplateVariableDef(key: "intendedMajor", label: "Intended major", category: "player",
                          sourceType: .column, sourcePath: "column:users.intended_major"),
      TemplateVariableDef(key: "programNote", label: "Program note", category: "program",
                          sourceType: .authored),
      TemplateVariableDef(key: "fitReason", label: "Fit reason", category: "program",
                          sourceType: .authored),
      TemplateVariableDef(key: "updateHook", label: "Recent update", category: "player",
                          sourceType: .authored),
      TemplateVariableDef(key: "metrics", label: "", category: "player",
                          sourceType: .computed, isRequiredDefault: false),
      TemplateVariableDef(key: "schoolCity", label: "City", category: "program",
                          sourceType: .column, sourcePath: "column:schools.city")
    ]
  }

  private func makeVM(questionnaireCompleted: Bool = false,
                      schoolCity: String? = nil) -> QuickCommunicationViewModel {
    var schools: [String: String] = [
      "questionnaire_completed": questionnaireCompleted ? "true" : "false"]
    if let schoolCity { schools["city"] = schoolCity }
    let ctx = TablesStubContext(schools: schools)
    return QuickCommunicationViewModel(
      coach: coach(), schoolName: "Duke University",
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: ctx,
      schoolsService: MockSchoolsService())
  }

  /// Body touching every collectible token, in a deliberately shuffled order to prove the
  /// output order comes from the builder, not first-seen in the text.
  private let allTokensBody = """
  {{metrics}} {{updateHook}} {{fitReason}} {{programNote}} \
  {{intendedMajor}} {{questionnaireNote}}
  """

  func test_allMissing_ordersRowsCanonically() async {
    let vm = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: allTokensBody))

    XCTAssertEqual(vm.missingInfoFields.map(\.id),
                   ["questionnaireNote", "intendedMajor", "programNote", "fitReason",
                    "updateHook", "metrics"])
    XCTAssertTrue(vm.hasMissingInfo)
  }

  func test_resolvedTemplate_hasNoMissingInfo() async {
    let vm = makeVM(schoolCity: "Durham")
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: "We love {{schoolCity}}."))

    XCTAssertTrue(vm.missingInfoFields.isEmpty)
    XCTAssertFalse(vm.hasMissingInfo)
  }

  func test_noTemplate_hasNoMissingInfo() async {
    let vm = makeVM()
    await vm.loadResolverInputs()
    XCTAssertTrue(vm.missingInfoFields.isEmpty)
    XCTAssertFalse(vm.hasMissingInfo)
  }

  func test_editorMapping_perSource() async {
    let vm = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: allTokensBody))
    let byId = Dictionary(uniqueKeysWithValues: vm.missingInfoFields.map { ($0.id, $0.editor) })

    XCTAssertEqual(byId["questionnaireNote"], .boolean)
    XCTAssertEqual(byId["intendedMajor"], .text(multiline: false))
    XCTAssertEqual(byId["programNote"], .text(multiline: true))
    XCTAssertEqual(byId["fitReason"], .text(multiline: true))
    XCTAssertEqual(byId["updateHook"], .text(multiline: false))
    XCTAssertEqual(byId["metrics"], .metricLink)
  }

  func test_specificityRows_areParentLocked() async {
    let vm = makeVM(questionnaireCompleted: false)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: allTokensBody))
    let byId = Dictionary(uniqueKeysWithValues: vm.missingInfoFields.map { ($0.id, $0.editableByParent) })

    XCTAssertEqual(byId["programNote"], false)
    XCTAssertEqual(byId["fitReason"], false)
    XCTAssertEqual(byId["updateHook"], true)
    XCTAssertEqual(byId["intendedMajor"], true)
  }

  func test_completeQuestionnaire_dropsBooleanRow() async {
    let vm = makeVM(questionnaireCompleted: true)
    await vm.loadResolverInputs()
    vm.selectTemplate(template(body: allTokensBody))

    XCTAssertFalse(vm.missingInfoFields.contains { $0.id == "questionnaireNote" },
                   "completed questionnaire produces no row")
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

private struct TablesStubContext: TemplateContextProviding {
  let schools: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: ["schools": schools], prefs: [:], authored: authored,
                    derived: [:], metrics: [], events: [], now: now)
  }
}
