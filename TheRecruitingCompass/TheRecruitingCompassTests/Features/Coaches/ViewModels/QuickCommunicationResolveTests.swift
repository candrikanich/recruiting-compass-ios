import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationResolveTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com",
          phone: nil, position: "Head Coach", schoolId: "s1",
          createdAt: "", updatedAt: "")
  }
  private func registry() -> [TemplateVariableDef] {
    [TemplateVariableDef(key: "coachSalutation", label: "", category: "program", sourceType: .computed),
     TemplateVariableDef(key: "programNote", label: "", category: "authored",
                         sourceType: .authored, isRequiredDefault: true)]
  }

  func test_resolvesKnownTokens_gatesOnUnresolved() async {
    let vm = QuickCommunicationViewModel(
      coach: coach(), schoolName: "Duke University",
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: StubContext(derived: ["coachSalutation": "Coach Smith"]))
    await vm.loadResolverInputs()
    vm.selectTemplate(CommunicationTemplate(
      id: "t1", userId: "", name: "Intro", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil,
      createdAt: "", updatedAt: "", subject: "Hi from {{coachSalutation}}"))

    XCTAssertEqual(vm.resolvedSubject, "Hi from Coach Smith")
    XCTAssertEqual(vm.resolvedBody, "Coach Smith, {{programNote}}")
    XCTAssertEqual(vm.unresolvedKeys, ["programNote"])
    XCTAssertTrue(vm.isSendBlocked)
  }

  func test_authoredValueUnblocksSend() async {
    let vm = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: StubTemplates(),
      templateVariablesService: StubRegistry(defs: registry()),
      contextService: StubContext(derived: ["coachSalutation": "Coach Smith"]))
    await vm.loadResolverInputs()
    vm.authoredValues["programNote"] = "loved the camp"
    vm.selectTemplate(CommunicationTemplate(
      id: "t1", userId: "", name: "Intro", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil, createdAt: "", updatedAt: ""))

    XCTAssertEqual(vm.resolvedBody, "Coach Smith, loved the camp")
    XCTAssertTrue(vm.unresolvedKeys.isEmpty)
    XCTAssertFalse(vm.isSendBlocked)
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

private struct StubContext: TemplateContextProviding {
  let derived: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: authored, derived: derived,
                    metrics: [], events: [], now: now)
  }
}
