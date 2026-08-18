import SwiftUI
import XCTest
@testable import TheRecruitingCompass

@MainActor
final class QuickCommunicationPanelTests: XCTestCase {
  nonisolated deinit {}

  private func coach() -> Coach {
    Coach(id: "c1", firstName: "Sam", lastName: "Smith", email: "s@x.com", phone: "555",
          position: "HC", schoolId: "s1", createdAt: "", updatedAt: "")
  }
  private func vm() async -> QuickCommunicationViewModel {
    let v = QuickCommunicationViewModel(
      coach: coach(), schoolName: nil, templatesService: PanelStubTemplates(),
      templateVariablesService: PanelStubRegistry(defs: [
        .init(key: "coachSalutation", label: "Coach Salutation", category: "", sourceType: .computed),
        .init(key: "programNote", label: "Program Note", category: "",
              sourceType: .authored, isRequiredDefault: true)]),
      contextService: PanelStubContext(derived: ["coachSalutation": "Coach Smith"]))
    await v.loadResolverInputs()
    return v
  }

  func test_referencedVariablesAndAuthoredBinding() async {
    let v = await vm()
    v.selectTemplate(CommunicationTemplate(id: "t", userId: "", name: "n", type: .email,
      body: "{{coachSalutation}}, {{programNote}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertEqual(v.referencedVariables.map(\.key), ["coachSalutation", "programNote"])
    XCTAssertTrue(v.isSendBlocked)

    v.authoredBinding(for: "programNote").wrappedValue = "loved the camp"
    XCTAssertEqual(v.effectiveBody, "Coach Smith, loved the camp")
    XCTAssertFalse(v.isSendBlocked)
    XCTAssertTrue(v.referencedVariables.first { $0.key == "programNote" }!.isResolved)
  }

  func test_editedBodyOverridesAndDrivesGate() async {
    let v = await vm()
    v.selectTemplate(CommunicationTemplate(id: "t", userId: "", name: "n", type: .message,
      body: "{{coachSalutation}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertEqual(v.effectiveBody, "Coach Smith")
    v.editedBody = String(repeating: "x", count: 161)
    XCTAssertTrue(v.textBodyOverLimit)
    XCTAssertTrue(v.unresolvedKeys.isEmpty, "edited text has no tokens")
  }

  func test_selectingTemplateClearsEdits() async {
    let v = await vm()
    v.editedBody = "stale"
    v.selectTemplate(CommunicationTemplate(id: "t2", userId: "", name: "n", type: .email,
      body: "{{coachSalutation}}", variables: nil, createdAt: "", updatedAt: ""))
    XCTAssertNil(v.editedBody)
    XCTAssertEqual(v.effectiveBody, "Coach Smith")
  }
}

private struct PanelStubTemplates: CommunicationTemplatesServicing {
  func fetchTemplates() async throws -> [CommunicationTemplate] { [] }
  func createTemplate(formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func updateTemplate(id: String, formData: TemplateFormData) async throws -> CommunicationTemplate { fatalError() }
  func deleteTemplate(id: String) async throws {}
}
private struct PanelStubRegistry: TemplateVariablesServicing {
  let defs: [TemplateVariableDef]
  func fetchRegistry() async throws -> [TemplateVariableDef] { defs }
}
private struct PanelStubContext: TemplateContextProviding {
  let derived: [String: String]
  func buildContext(coach: Coach, school: School?, athleteUserId: String?,
                    authored: [String: String], now: Date) async -> ResolverContext {
    ResolverContext(tables: [:], prefs: [:], authored: authored, derived: derived,
                    metrics: [], events: [], now: now)
  }
}
