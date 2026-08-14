import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationWindowTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func tpl(_ id: String, window: String?, stage: String) -> CommunicationTemplate {
    CommunicationTemplate(id: id, userId: "", name: id, type: .email, body: "b",
      variables: nil, createdAt: "", updatedAt: "", slug: id, stage: stage, contactWindow: window)
  }

  private func makeVM(division: String?, gradYear: String?, rules: [ContactWindowRule]) async
    -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil,
      templatesService: WindowStubTemplates(),
      templateVariablesService: WindowStubRegistry(),
      contextService: WindowStubContext(division: division, gradYear: gradYear, sport: "baseball"),
      contactWindowService: MockContactWindowService(rules: rules))
    await v.loadResolverInputs()
    v.templates = [tpl("intro-pre", window: "pre", stage: "intro"),
                   tpl("intro-any", window: "any", stage: "intro"),
                   tpl("followup", window: "any", stage: "followup")]
    return v
  }

  func test_openState_hidesPreTemplates() async {
    let v = await makeVM(division: "D3", gradYear: "2027",
      rules: [ContactWindowRule(sport: "*", division: "D3", ruleKind: "unrestricted",
                                reference: nil, windowDate: nil, notes: nil)])
    XCTAssertEqual(v.contactWindowState, .open)
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-any", "followup"])
  }

  func test_preState_swapsAnyForPreSibling() async {
    let v = await makeVM(division: "D1", gradYear: "2030",
      rules: [ContactWindowRule(sport: "baseball", division: "D1", ruleKind: "date_before_grade",
                                reference: "junior", windowDate: "Aug 1", notes: nil)])
    XCTAssertEqual(v.contactWindowState, .pre)
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-pre", "followup"])
  }

  func test_missingContext_failsOpen() async {
    let v = await makeVM(division: nil, gradYear: nil, rules: [])
    XCTAssertEqual(v.contactWindowState, .open)
    XCTAssertEqual(v.emailTemplates.map(\.id), ["intro-any", "followup"])
  }
}

private struct WindowStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct WindowStubRegistry: TemplateVariablesServicing {
  func fetchRegistry() async throws -> [TemplateVariableDef] { [] }
}
private struct WindowStubContext: TemplateContextProviding {
  let division: String?; let gradYear: String?; let sport: String
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    var tables: [String: [String: String]] = [:]
    if let division { tables["schools"] = ["division": division] }
    if let gradYear { tables["users"] = ["graduation_year": gradYear] }
    return ResolverContext(tables: tables, prefs: [:], authored: authored,
                           derived: ["sport": sport], metrics: [], events: [], now: now)
  }
}
