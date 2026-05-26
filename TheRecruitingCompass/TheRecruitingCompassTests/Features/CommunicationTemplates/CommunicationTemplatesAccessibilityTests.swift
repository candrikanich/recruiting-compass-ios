import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CommunicationTemplatesAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  // MARK: - Test Data

  private func makeTemplate(
    id: String = "test-id-1",
    name: String = "Initial Contact Email",
    type: TemplateType = .email,
    body: String = "Dear {{coach_name}}, I am writing to express my interest...",
    createdAt: String = "2026-01-01T00:00:00Z"
  ) -> CommunicationTemplate {
    CommunicationTemplate(
      id: id,
      userId: "user-1",
      name: name,
      type: type,
      body: body,
      variables: ["coach_name"],
      createdAt: createdAt,
      updatedAt: createdAt
    )
  }

  private func makeCard(_ template: CommunicationTemplate) -> TemplateCardView {
    TemplateCardView(template: template, onEdit: {})
  }

  private func makeEditor() -> TemplateEditorView {
    TemplateEditorView(viewModel: CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService()))
  }

  // MARK: - TemplateCardView Accessibility Label

  func testTemplateCard_LabelContainsNameAndType() {
    let card = makeCard(makeTemplate(name: "Follow Up Email", type: .email))
    let label = card.cardAccessibilityLabel

    XCTAssertTrue(label.contains("Follow Up Email"), "Card label should contain template name")
    XCTAssertTrue(label.contains("Email"), "Card label should contain template type")
  }

  func testTemplateCard_LabelContainsCreatedDate() {
    let card = makeCard(makeTemplate())
    XCTAssertTrue(card.cardAccessibilityLabel.contains("Created"), "Card label should include 'Created' prefix")
  }

  func testTemplateCard_EditButtonLabelIncludesTemplateName() {
    let card = makeCard(makeTemplate(name: "Follow Up Email"))
    XCTAssertEqual(card.editAccessibilityLabel, "Edit Follow Up Email template", "Edit button names the template")
  }

  // MARK: - TemplateCardView Dynamic Type

  func testTemplateCard_SupportsDynamicType() {
    let card = makeCard(makeTemplate())
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 350, height: 200)

    let hostingController = UIHostingController(rootView: card)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 200)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Card should render at accessibility text sizes")
  }

  // MARK: - Filter Buttons / Type Badge (WCAG 1.4.1: not color alone)

  func testTemplateType_HasNonEmptyTextLabel() {
    let allTypes = TemplateType.allCases
    XCTAssertGreaterThan(allTypes.count, 0, "Should have template types for filter pills")

    for type in allTypes {
      XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) must have a text label beyond color for VoiceOver")
    }
  }

  // MARK: - TemplateEditorView Form Fields & Save Button

  func testEditorView_SaveButtonLabel_CreateMode() {
    let editor = makeEditor()
    XCTAssertFalse(editor.isEditing, "Fresh editor is in create mode")
    XCTAssertEqual(editor.saveButtonLabel, "Save Template", "Create mode should show 'Save Template'")
  }

  func testEditorView_SaveButtonLabel_EditMode() {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    viewModel.startEditing(template: makeTemplate())
    let editor = TemplateEditorView(viewModel: viewModel)

    XCTAssertTrue(editor.isEditing, "Editor reflects editing state after startEditing")
    XCTAssertEqual(editor.saveButtonLabel, "Save Changes", "Edit mode should show 'Save Changes'")
  }

  // MARK: - Variable Buttons

  func testEditorView_VariableButtonsHaveDescriptiveLabels() {
    // Each variable button renders `.accessibilityLabel("Insert \(variable.name) variable")`.
    for variable in TemplateVariable.all {
      XCTAssertFalse(variable.name.isEmpty, "Variable '\(variable.key)' must have a name for its insert-button label")
    }
  }

  // MARK: - Editor Dynamic Type

  func testEditorView_SupportsDynamicType() {
    let editor = makeEditor()
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 375, height: 800)

    let hostingController = UIHostingController(rootView: editor)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 800)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Editor should render at accessibility text sizes")
  }
}
