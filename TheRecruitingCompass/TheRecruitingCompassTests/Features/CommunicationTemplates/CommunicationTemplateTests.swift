import XCTest
@testable import TheRecruitingCompass

final class CommunicationTemplateTests: XCTestCase {

  // MARK: - bodyPreview Tests

  func testBodyPreview_ShortString_ReturnsAsIs() {
    let template = makeTemplate(body: "Short body text")
    XCTAssertEqual(template.bodyPreview, "Short body text")
  }

  func testBodyPreview_Exactly100Chars_ReturnsAsIs() {
    let body = String(repeating: "a", count: 100)
    let template = makeTemplate(body: body)
    XCTAssertEqual(template.bodyPreview, body)
    XCTAssertEqual(template.bodyPreview.count, 100)
  }

  func testBodyPreview_Over100Chars_TruncatesWithEllipsis() {
    let body = String(repeating: "b", count: 150)
    let template = makeTemplate(body: body)
    let expected = String(repeating: "b", count: 100) + "..."
    XCTAssertEqual(template.bodyPreview, expected)
    XCTAssertEqual(template.bodyPreview.count, 103)
  }

  func testBodyPreview_EmptyString_ReturnsEmpty() {
    let template = makeTemplate(body: "")
    XCTAssertEqual(template.bodyPreview, "")
  }

  // MARK: - typeDisplayName Tests

  func testTypeDisplayName_Email() {
    let template = makeTemplate(type: .email)
    XCTAssertEqual(template.typeDisplayName, "Email")
  }

  func testTypeDisplayName_Text() {
    let template = makeTemplate(type: .text)
    XCTAssertEqual(template.typeDisplayName, "Text")
  }

  func testTypeDisplayName_Twitter() {
    let template = makeTemplate(type: .twitter)
    XCTAssertEqual(template.typeDisplayName, "Twitter")
  }

  // MARK: - formattedDate Tests

  func testFormattedDate_ReturnsNonEmptyString() {
    let template = makeTemplate()
    XCTAssertFalse(template.formattedDate.isEmpty)
  }

  // MARK: - TemplateType Tests

  func testTemplateType_AllCasesExist() {
    XCTAssertEqual(TemplateType.allCases.count, 3)
    XCTAssertTrue(TemplateType.allCases.contains(.email))
    XCTAssertTrue(TemplateType.allCases.contains(.text))
    XCTAssertTrue(TemplateType.allCases.contains(.twitter))
  }

  func testTemplateType_RawValues() {
    XCTAssertEqual(TemplateType.email.rawValue, "email")
    XCTAssertEqual(TemplateType.text.rawValue, "text")
    XCTAssertEqual(TemplateType.twitter.rawValue, "twitter")
  }

  func testTemplateType_DisplayNames() {
    XCTAssertEqual(TemplateType.email.displayName, "Email")
    XCTAssertEqual(TemplateType.text.displayName, "Text")
    XCTAssertEqual(TemplateType.twitter.displayName, "Twitter")
  }

  // MARK: - TemplateFormData Tests

  func testFormData_IsValid_FalseWhenNameEmpty() {
    var formData = TemplateFormData()
    formData.name = ""
    formData.body = "Some body"
    XCTAssertFalse(formData.isValid)
  }

  func testFormData_IsValid_FalseWhenNameOnlyWhitespace() {
    var formData = TemplateFormData()
    formData.name = "   "
    formData.body = "Some body"
    XCTAssertFalse(formData.isValid)
  }

  func testFormData_IsValid_FalseWhenBodyEmpty() {
    var formData = TemplateFormData()
    formData.name = "Template Name"
    formData.body = ""
    XCTAssertFalse(formData.isValid)
  }

  func testFormData_IsValid_FalseWhenBodyOnlyWhitespace() {
    var formData = TemplateFormData()
    formData.name = "Template Name"
    formData.body = "   "
    XCTAssertFalse(formData.isValid)
  }

  func testFormData_IsValid_TrueWhenBothFilled() {
    var formData = TemplateFormData()
    formData.name = "My Template"
    formData.body = "Hello {{coach_name}}"
    XCTAssertTrue(formData.isValid)
  }

  func testFormData_IsValid_FalseWhenBothEmpty() {
    let formData = TemplateFormData()
    XCTAssertFalse(formData.isValid)
  }

  func testFormData_DefaultInit_HasDefaults() {
    let formData = TemplateFormData()
    XCTAssertEqual(formData.name, "")
    XCTAssertEqual(formData.type, .email)
    XCTAssertEqual(formData.body, "")
  }

  func testFormData_InitFromTemplate_PopulatesCorrectly() {
    let template = makeTemplate(
      name: "Recruiting Email",
      type: .text,
      body: "Hey {{coach_name}}, I am interested."
    )
    let formData = TemplateFormData(from: template)
    XCTAssertEqual(formData.name, "Recruiting Email")
    XCTAssertEqual(formData.type, .text)
    XCTAssertEqual(formData.body, "Hey {{coach_name}}, I am interested.")
  }

  // MARK: - bodyFilled / substituteVariables Tests

  func testBodyFilled_ReplacesKnownVariables() {
    let template = makeTemplate(body: "Hi {{coach_name}}, from {{school_name}}.")
    let values = ["coach_name": "Coach Smith", "school_name": "State U"]
    XCTAssertEqual(template.bodyFilled(with: values), "Hi Coach Smith, from State U.")
  }

  func testBodyFilled_UnknownVariable_BecomesPlaceholder() {
    let template = makeTemplate(body: "Hi {{coach_name}}, athlete: {{athlete_name}}.")
    let values = ["coach_name": "Coach Smith"]
    XCTAssertEqual(template.bodyFilled(with: values), "Hi Coach Smith, athlete: [Athlete Name].")
  }

  func testSubstituteVariables_EmptyValues_LeavesPlaceholders() {
    let body = "Hello {{coach_name}}"
    let result = CommunicationTemplate.substituteVariables(in: body, values: [:])
    XCTAssertEqual(result, "Hello [Coach Name]")
  }

  func testSubstituteVariables_NoPlaceholders_ReturnsOriginal() {
    let body = "Plain text"
    let result = CommunicationTemplate.substituteVariables(in: body, values: ["coach_name": "X"])
    XCTAssertEqual(result, "Plain text")
  }

  // MARK: - Helpers

  private func makeTemplate(
    id: String = "template-1",
    name: String = "Test Template",
    type: TemplateType = .email,
    body: String = "Test body content"
  ) -> CommunicationTemplate {
    CommunicationTemplate(
      id: id,
      userId: "user-1",
      name: name,
      type: type,
      body: body,
      variables: nil,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }
}
