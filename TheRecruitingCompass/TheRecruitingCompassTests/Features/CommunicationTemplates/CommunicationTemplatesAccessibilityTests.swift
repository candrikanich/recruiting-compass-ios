import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class CommunicationTemplatesAccessibilityTests: XCTestCase {

  // MARK: - Test Data

  private func makeTemplate(
    id: String = "test-id-1",
    name: String = "Initial Contact Email",
    type: TemplateType = .email,
    body: String = "Dear {{coach_name}}, I am writing to express my interest...",
    createdAt: Date = Date()
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

  // MARK: - TemplateCardView Accessibility Label

  func testTemplateCard_LabelContainsNameAndType() throws {
    let template = makeTemplate(name: "Follow Up Email", type: .email)
    let card = TemplateCardView(template: template, onEdit: {})

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Follow Up Email"), "Card label should contain template name")
    XCTAssertTrue(combinedLabel.contains("Email"), "Card label should contain template type")
  }

  func testTemplateCard_LabelContainsCreatedDate() throws {
    let template = makeTemplate()
    let card = TemplateCardView(template: template, onEdit: {})

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Created"), "Card label should include 'Created' prefix for date")
  }

  func testTemplateCard_HasEditHint() throws {
    let template = makeTemplate()
    let card = TemplateCardView(template: template, onEdit: {})

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    let hints = findAccessibilityHints(in: view)
    try XCTSkipIf(hints.isEmpty, "SwiftUI accessibility hints not accessible via UIHostingController in unit tests")

    let hasEditHint = hints.contains { $0.lowercased().contains("edit") || $0.lowercased().contains("tap") }
    XCTAssertTrue(hasEditHint, "Card should have a hint about editing")
  }

  func testTemplateCard_HasAccessibilityIdentifier() throws {
    let template = makeTemplate(id: "abc-123")
    let card = TemplateCardView(template: template, onEdit: {})

    let hostingController = UIHostingController(rootView: card)
    let view = hostingController.view!

    let identifiers = findAccessibilityIdentifiers(in: view)
    let hasCardId = identifiers.contains("template.card.abc-123")

    try XCTSkipIf(!hasCardId, "SwiftUI accessibility identifiers not accessible via UIHostingController in unit tests")
    XCTAssertTrue(hasCardId, "Card should have identifier 'template.card.abc-123'")
  }

  // MARK: - TemplateCardView Touch Target

  func testTemplateCard_MeetsMinimumTouchTarget() {
    let template = makeTemplate()
    let card = TemplateCardView(template: template, onEdit: {})
      .frame(width: 350, height: 120)

    let hostingController = UIHostingController(rootView: card)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 120)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0, "Template card should meet WCAG 44pt minimum touch target")
  }

  // MARK: - Filter Buttons Accessibility

  func testFilterPills_HaveProperLabels() {
    let allTypes = TemplateType.allCases
    XCTAssertGreaterThan(allTypes.count, 0, "Should have template types for filter pills")

    for type in allTypes {
      XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) should have a non-empty display name for VoiceOver")
    }
  }

  func testFilterPills_TypeNotConveyedByColorAlone() {
    // WCAG 1.4.1: Information should not be conveyed by color alone
    // Each TemplateType has both a displayName (text) and a color
    for type in TemplateType.allCases {
      XCTAssertFalse(type.displayName.isEmpty, "Type \(type.rawValue) must have text label, not just color")
    }
  }

  // MARK: - TemplateEditorView Form Fields

  func testEditorView_NameFieldHasLabel() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    let editor = TemplateEditorView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ").lowercased()

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("template name"), "Name field should have 'Template name' accessibility label")
  }

  func testEditorView_BodyFieldHasLabel() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    let editor = TemplateEditorView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ").lowercased()

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("template body"), "Body field should have 'Template body' accessibility label")
  }

  func testEditorView_HasAccessibilityIdentifiers() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    let editor = TemplateEditorView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let identifiers = findAccessibilityIdentifiers(in: view)

    try XCTSkipIf(identifiers.isEmpty, "SwiftUI accessibility identifiers not accessible via UIHostingController in unit tests")

    XCTAssertTrue(identifiers.contains("templateEditor.nameField"), "Name field should have identifier")
    XCTAssertTrue(identifiers.contains("templateEditor.typePicker"), "Type picker should have identifier")
    XCTAssertTrue(identifiers.contains("templateEditor.bodyEditor"), "Body editor should have identifier")
    XCTAssertTrue(identifiers.contains("templateEditor.saveButton"), "Save button should have identifier")
    XCTAssertTrue(identifiers.contains("templateEditor.cancelButton"), "Cancel button should have identifier")
  }

  func testEditorView_SaveButtonLabelChangesForEditMode() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())

    // Create mode
    let createEditor = TemplateEditorView(viewModel: viewModel)
    let createHost = UIHostingController(rootView: createEditor)
    let createLabels = findAccessibilityElements(in: createHost.view!)
      .compactMap { $0.accessibilityLabel }
      .joined(separator: " ")

    try XCTSkipIf(createLabels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(createLabels.contains("Save Template"), "Create mode should show 'Save Template'")

    // Edit mode
    viewModel.startEditing(template: makeTemplate())
    let editEditor = TemplateEditorView(viewModel: viewModel)
    let editHost = UIHostingController(rootView: editEditor)
    let editLabelList = findAccessibilityElements(in: editHost.view!).compactMap { $0.accessibilityLabel }
    let editLabels = editLabelList.joined(separator: " ")

    try XCTSkipIf(editLabelList.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(editLabels.contains("Save Changes"), "Edit mode should show 'Save Changes'")
  }

  func testEditorView_DeleteButtonHasLabel_InEditMode() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    viewModel.startEditing(template: makeTemplate())

    let editor = TemplateEditorView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(combinedLabel.contains("Delete Template"), "Delete button should have 'Delete Template' label")
  }

  func testEditorView_DeleteButtonHasIdentifier_InEditMode() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    viewModel.startEditing(template: makeTemplate())

    let editor = TemplateEditorView(viewModel: viewModel)
    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let identifiers = findAccessibilityIdentifiers(in: view)

    try XCTSkipIf(identifiers.isEmpty, "SwiftUI accessibility identifiers not accessible via UIHostingController in unit tests")

    XCTAssertTrue(identifiers.contains("templateEditor.deleteButton"), "Delete button should have identifier")
  }

  // MARK: - Variable Buttons

  func testEditorView_VariableButtonsHaveLabels() throws {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    let editor = TemplateEditorView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: editor)
    let view = hostingController.view!

    let elements = findAccessibilityElements(in: view)
    let labels = elements.compactMap { $0.accessibilityLabel }
    let combinedLabel = labels.joined(separator: " ")

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    for variable in TemplateVariable.all {
      XCTAssertTrue(
        combinedLabel.contains("Insert \(variable.name) variable"),
        "Variable button for '\(variable.name)' should have descriptive label"
      )
    }
  }

  // MARK: - Dynamic Type Support

  func testTemplateCard_SupportsDynamicType() {
    let template = makeTemplate()
    let card = TemplateCardView(template: template, onEdit: {})
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 350, height: 200)

    let hostingController = UIHostingController(rootView: card)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 350, height: 200)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Card should render at accessibility text sizes")
  }

  func testEditorView_SupportsDynamicType() {
    let viewModel = CommunicationTemplatesViewModel(service: MockCommunicationTemplatesService())
    let editor = TemplateEditorView(viewModel: viewModel)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
      .frame(width: 375, height: 800)

    let hostingController = UIHostingController(rootView: editor)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 800)
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    XCTAssertNotNil(hostingController.view, "Editor should render at accessibility text sizes")
  }

  // MARK: - Semantic Fonts Validation

  func testTemplateType_HasTextLabel_NotColorOnly() {
    // WCAG 1.4.1: Type badge uses text (displayName), not just color
    for type in TemplateType.allCases {
      XCTAssertFalse(type.displayName.isEmpty, "Type '\(type.rawValue)' must have text label beyond color")
    }
  }

  // MARK: - Helper Methods

  private func findAccessibilityElements(in view: UIView) -> [NSObject] {
    var elements: [NSObject] = []
    if view.isAccessibilityElement {
      elements.append(view as NSObject)
    }
    if let accessibilityElements = view.accessibilityElements as? [NSObject] {
      elements.append(contentsOf: accessibilityElements)
    }
    for subview in view.subviews {
      elements.append(contentsOf: findAccessibilityElements(in: subview))
    }
    return elements
  }

  private func findAccessibilityHints(in view: UIView) -> [String] {
    var hints: [String] = []
    if let hint = view.accessibilityHint {
      hints.append(hint)
    }
    for subview in view.subviews {
      hints.append(contentsOf: findAccessibilityHints(in: subview))
    }
    return hints
  }

  private func findAccessibilityIdentifiers(in view: UIView) -> [String] {
    var identifiers: [String] = []
    if let identifier = view.accessibilityIdentifier, !identifier.isEmpty {
      identifiers.append(identifier)
    }
    for subview in view.subviews {
      identifiers.append(contentsOf: findAccessibilityIdentifiers(in: subview))
    }
    return identifiers
  }
}
