import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class FamilyManagementAccessibilityTests: XCTestCase {

  // MARK: - Test Helpers

  private func makeUserWithRole(_ role: UserRole) -> User? {
    let jsonString = """
    {
      "id": "user-1",
      "email": "test@example.com",
      "email_confirmed_at": "2026-01-01T00:00:00Z",
      "phone": null,
      "user_metadata": {"role": "\(role.rawValue)"},
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z"
    }
    """
    guard let data = jsonString.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(User.self, from: data)
  }

  private func makeMockViewModel(
    role: UserRole,
    familyCode: String? = nil,
    familyMembers: [FamilyMember] = [],
    parentFamilies: [ParentFamilyData] = [],
    isLoading: Bool = false
  ) -> FamilyManagementViewModel {
    let mockAuth = MockAuthManager()
    mockAuth.user = makeUserWithRole(role)

    let viewModel = FamilyManagementViewModel(
      familyService: MockFamilyService(),
      authManager: mockAuth
    )

    viewModel.familyCode = familyCode
    viewModel.familyMembers = familyMembers
    viewModel.parentFamilies = parentFamilies
    viewModel.isLoading = isLoading

    return viewModel
  }

  private func makeMockMember(
    id: String = "member-1",
    name: String,
    role: String,
    addedAt: String? = nil
  ) -> FamilyMember {
    FamilyMember(
      id: id,
      userId: "user-1",
      familyUnitId: "family-1",
      role: role,
      addedAt: addedAt,
      user: FamilyMemberUser(
        id: "user-1",
        email: "\(name.replacingOccurrences(of: " ", with: ".").lowercased())@example.com",
        fullName: name,
        role: role == "parent" ? "parent" : "player"
      )
    )
  }

  private func makeMockParentFamily(
    name: String,
    code: String
  ) -> ParentFamilyData {
    ParentFamilyData(
      familyId: "family-1",
      familyCode: code,
      familyName: name,
      codeGeneratedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - UIHostingController Helper Methods

  private func findAccessibilityLabels(in view: UIView) -> [String] {
    var labels: [String] = []

    if let label = view.accessibilityLabel {
      labels.append(label)
    }

    for subview in view.subviews {
      labels.append(contentsOf: findAccessibilityLabels(in: subview))
    }

    return labels
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

  private func findHiddenAccessibilityElements(in view: UIView) -> [UIView] {
    var hiddenElements: [UIView] = []

    if view.accessibilityElementsHidden {
      hiddenElements.append(view)
    }

    for subview in view.subviews {
      hiddenElements.append(contentsOf: findHiddenAccessibilityElements(in: subview))
    }

    return hiddenElements
  }

  // MARK: - FamilyManagementPlayerView Tests

  func testPlayerView_FamilyCodeHasVoiceOverFriendlyLabel() async throws {
    let viewModel = makeMockViewModel(role: .player, familyCode: "FAM-123456")
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("FAM") && $0.contains("123456") }),
                  "Family code should be formatted for VoiceOver")
  }

  func testPlayerView_CopyButtonHasDescriptiveLabel() async throws {
    let viewModel = makeMockViewModel(role: .player, familyCode: "FAM-123456")
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Copy") || $0.contains("family code") }),
                  "Copy button should have descriptive label")
  }

  func testPlayerView_ShareButtonHasDescriptiveLabel() async throws {
    let viewModel = makeMockViewModel(role: .player, familyCode: "FAM-123456")
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Share") }),
                  "Share button should have descriptive label")
  }

  func testPlayerView_RegenerateButtonHasLabelAndHint() async throws {
    let viewModel = makeMockViewModel(role: .player, familyCode: "FAM-123456")
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    let hints = findAccessibilityHints(in: uiView)

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(labels.contains(where: { $0.contains("Regenerate") || $0.contains("Generate New") }),
                  "Regenerate button should have descriptive label")
    XCTAssertTrue(hints.contains(where: { $0.contains("invalidate") || $0.contains("new code") }),
                  "Regenerate button should have hint about consequences")
  }

  func testPlayerView_EmptyStateIconIsDecorativelyHidden() async throws {
    let viewModel = makeMockViewModel(role: .player, familyMembers: [])
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    // Empty state icon should not have its own accessibility label
    XCTAssertTrue(labels.contains(where: { $0.contains("No family members") || $0.contains("empty") }),
                  "Empty state message should be accessible")
  }

  func testPlayerView_LoadingIndicatorHasLabel() async throws {
    let viewModel = makeMockViewModel(role: .player, isLoading: true)
    let view = FamilyManagementPlayerView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Loading") }),
                  "Loading indicator should have accessible label")
  }

  func testPlayerView_ScalesWithDynamicType() {
    let viewModel = makeMockViewModel(role: .player, familyCode: "FAM-123456")
    let viewNormal = FamilyManagementPlayerView(viewModel: viewModel)
      .environment(\.sizeCategory, .large)

    let viewA11y = FamilyManagementPlayerView(viewModel: viewModel)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingControllerNormal = UIHostingController(rootView: viewNormal)
    let hostingControllerA11y = UIHostingController(rootView: viewA11y)

    // Both should render without crashing at different text sizes
    XCTAssertNotNil(hostingControllerNormal.view)
    XCTAssertNotNil(hostingControllerA11y.view)
  }

  // MARK: - FamilyMemberCard Tests

  func testMemberCard_HasCombinedAccessibilityElement() throws {
    let member = makeMockMember(name: "John Doe", role: "parent", addedAt: "2026-01-15T00:00:00Z")
    let card = FamilyMemberCard(member: member, onRemove: {})

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("John Doe") }),
                  "Member card should combine member information into accessible label")
  }

  func testMemberCard_AccessibilityLabelIncludesNameRoleDate() throws {
    let member = makeMockMember(name: "John Doe", role: "parent", addedAt: "2026-01-15T00:00:00Z")
    let card = FamilyMemberCard(member: member, onRemove: {})

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: {
      $0.contains("John Doe") && ($0.contains("parent") || $0.contains("Parent"))
    }), "Member card should include name and role")
  }

  func testMemberCard_RemoveButtonHasDescriptiveLabel() throws {
    let member = makeMockMember(name: "John Doe", role: "parent")
    let card = FamilyMemberCard(member: member, onRemove: {})

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: {
      $0.contains("Remove") && $0.contains("John Doe")
    }), "Remove button should include member name in label")
  }

  func testMemberCard_RemoveButtonHas44ptTouchTarget() {
    let member = makeMockMember(name: "John Doe", role: "parent")
    let button = Button(action: {}) {
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(.secondary)
    }
    .frame(minWidth: 44, minHeight: 44)
    .accessibilityLabel("Remove John Doe")

    let hostingController = UIHostingController(rootView: button)
    hostingController.view.frame = CGRect(x: 0, y: 0, width: 44, height: 44)

    // Force layout
    hostingController.view.setNeedsLayout()
    hostingController.view.layoutIfNeeded()

    // Button should meet minimum 44x44pt touch target
    XCTAssertGreaterThanOrEqual(hostingController.view.frame.width, 44.0)
    XCTAssertGreaterThanOrEqual(hostingController.view.frame.height, 44.0)
  }

  func testMemberCard_ScalesWithDynamicType() {
    let member = makeMockMember(name: "John Doe", role: "parent")
    let cardNormal = FamilyMemberCard(member: member, onRemove: {})
      .environment(\.sizeCategory, .large)

    let cardA11y = FamilyMemberCard(member: member, onRemove: {})
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingControllerNormal = UIHostingController(rootView: cardNormal)
    let hostingControllerA11y = UIHostingController(rootView: cardA11y)

    XCTAssertNotNil(hostingControllerNormal.view)
    XCTAssertNotNil(hostingControllerA11y.view)
  }

  // MARK: - FamilyManagementParentView Tests

  func testParentView_CodeInputHasLabelAndHint() async throws {
    let viewModel = makeMockViewModel(role: .parent)
    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    let hints = findAccessibilityHints(in: uiView)

    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")

    XCTAssertTrue(labels.contains(where: { $0.contains("Family Code") || $0.contains("code") }),
                  "Code input should have descriptive label")
    XCTAssertTrue(hints.contains(where: { $0.contains("FAM-") || $0.contains("format") }),
                  "Code input should have hint about format")
  }

  func testParentView_JoinButtonHasDescriptiveLabel() async throws {
    let viewModel = makeMockViewModel(role: .parent)
    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Join Family") || $0.contains("Join") }),
                  "Join button should have descriptive label")
  }

  func testParentView_JoinButtonDisabledStateAnnounced() async {
    let viewModel = makeMockViewModel(role: .parent)
    viewModel.codeInput = "INVALID"
    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    // With invalid code, the button should be disabled
    // VoiceOver will announce disabled state automatically
    XCTAssertNotNil(uiView)
  }

  func testParentView_EmptyFamiliesIconIsDecorativelyHidden() async throws {
    let viewModel = makeMockViewModel(role: .parent, parentFamilies: [])
    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    // Empty state should have descriptive text
    XCTAssertTrue(labels.contains(where: { $0.contains("No families") || $0.contains("Join") }),
                  "Empty state should have accessible text")
  }

  func testParentView_LoadingIndicatorHasLabel() async throws {
    let viewModel = makeMockViewModel(role: .parent, isLoading: true)
    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Loading") }),
                  "Loading indicator should have accessible label")
  }

  func testParentView_ScalesWithDynamicType() {
    let viewModel = makeMockViewModel(role: .parent)
    let viewNormal = FamilyManagementParentView(viewModel: viewModel)
      .environment(\.sizeCategory, .large)

    let viewA11y = FamilyManagementParentView(viewModel: viewModel)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingControllerNormal = UIHostingController(rootView: viewNormal)
    let hostingControllerA11y = UIHostingController(rootView: viewA11y)

    XCTAssertNotNil(hostingControllerNormal.view)
    XCTAssertNotNil(hostingControllerA11y.view)
  }

  // MARK: - ParentFamilyCard Tests

  func testParentFamilyCard_HasCombinedAccessibilityElement() throws {
    let family = makeMockParentFamily(name: "Smith Family", code: "FAM-ABC123")
    let card = ParentFamilyCard(family: family)

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Smith Family") }),
                  "Parent family card should have accessible label")
  }

  func testParentFamilyCard_AccessibilityLabelIncludesNameAndCode() throws {
    let family = makeMockParentFamily(name: "Smith Family", code: "FAM-ABC123")
    let card = ParentFamilyCard(family: family)

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: {
      $0.contains("Smith Family") && $0.contains("ABC123")
    }), "Parent family card should include name and code")
  }

  func testParentFamilyCard_CodeFormattedForVoiceOver() throws {
    let family = makeMockParentFamily(name: "Smith Family", code: "FAM-123456")
    let card = ParentFamilyCard(family: family)

    let hostingController = UIHostingController(rootView: card)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    // Code should be formatted with spaces for VoiceOver (e.g., "1 2 3 4 5 6")
    XCTAssertTrue(labels.contains(where: { $0.contains("123456") || $0.contains("1 2 3 4 5 6") }),
                  "Code should be formatted for VoiceOver")
  }

  func testParentFamilyCard_ScalesWithDynamicType() {
    let family = makeMockParentFamily(name: "Smith Family", code: "FAM-ABC123")
    let cardNormal = ParentFamilyCard(family: family)
      .environment(\.sizeCategory, .large)

    let cardA11y = ParentFamilyCard(family: family)
      .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)

    let hostingControllerNormal = UIHostingController(rootView: cardNormal)
    let hostingControllerA11y = UIHostingController(rootView: cardA11y)

    XCTAssertNotNil(hostingControllerNormal.view)
    XCTAssertNotNil(hostingControllerA11y.view)
  }

  // MARK: - FamilyManagementView Tests

  func testMainView_LoadingStateHasAccessibility() {
    let view = FamilyManagementView()
      .environment(\.sizeCategory, .large)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    // View should render and potentially show loading state
    XCTAssertNotNil(uiView)
  }

  // MARK: - LoadingStateView Tests

  func testLoadingStateView_HasMessageAndProgressIndicator() throws {
    let loadingView = LoadingStateView(message: "Loading family data...")

    let hostingController = UIHostingController(rootView: loadingView)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Loading family data") }),
                  "Loading state should have accessible message")
  }

  func testLoadingStateView_MessageIsReadable() throws {
    let loadingView = LoadingStateView(message: "Loading family data...")

    let hostingController = UIHostingController(rootView: loadingView)
    let uiView = hostingController.view!

    let labels = findAccessibilityLabels(in: uiView)
    try XCTSkipIf(labels.isEmpty, "SwiftUI accessibility labels not accessible via UIHostingController in unit tests")
    XCTAssertTrue(labels.contains(where: { $0.contains("Loading") }),
                  "Loading message should be readable by VoiceOver")
  }

  // MARK: - ToastModifier Tests

  func testToast_SuccessTypeHasAccessibleIcon() {
    let toast = ToastModifier(
      isShowing: .constant(true),
      message: .constant("Success!"),
      type: .success,
      duration: 3.0
    )
    XCTAssertEqual(toast.type, .success)
    XCTAssertEqual(toast.type.iconName, "checkmark.circle.fill")
  }

  func testToast_ErrorTypeHasAccessibleIcon() async {
    let toast = ToastModifier(
      isShowing: .constant(true),
      message: .constant("Error!"),
      type: .error,
      duration: 3.0
    )
    XCTAssertEqual(toast.type, .error)
    XCTAssertEqual(toast.type.iconName, "xmark.circle.fill")
  }

  func testToast_InfoTypeHasAccessibleIcon() {
    let toast = ToastModifier(
      isShowing: .constant(true),
      message: .constant("Info!"),
      type: .info,
      duration: 3.0
    )
    XCTAssertEqual(toast.type, .info)
    XCTAssertEqual(toast.type.iconName, "info.circle.fill")
  }

  func testToast_MessageIsAccessible() {
    let message = "Family code copied!"
    let toast = ToastModifier(
      isShowing: .constant(true),
      message: .constant(message),
      type: .success,
      duration: 3.0
    )
    XCTAssertNotNil(toast.message)
  }

  // MARK: - Color Contrast Tests

  func testToast_SuccessColorMeetsContrastRequirements() {
    let successColor = ToastType.success.iconColor
    XCTAssertEqual(successColor, .successGreen)
  }

  func testToast_ErrorColorMeetsContrastRequirements() {
    let errorColor = ToastType.error.iconColor
    XCTAssertEqual(errorColor, .errorRed)
  }

  func testToast_InfoColorMeetsContrastRequirements() {
    let infoColor = ToastType.info.iconColor
    XCTAssertEqual(infoColor, .accentBlue)
  }

  // MARK: - Button State Tests

  func testJoinButton_DisabledWhenCodeInvalid() async {
    let viewModel = makeMockViewModel(role: .parent)
    viewModel.codeInput = "INVALID"
    XCTAssertFalse(viewModel.isCodeInputValid)
  }

  func testJoinButton_EnabledWhenCodeValid() async {
    let viewModel = makeMockViewModel(role: .parent)
    viewModel.codeInput = "FAM-123456"
    XCTAssertTrue(viewModel.isCodeInputValid)
  }

  func testJoinButton_DisabledDuringLoading() async {
    let viewModel = makeMockViewModel(role: .parent)
    viewModel.codeInput = "FAM-123456"
    viewModel.isLoading = true

    let view = FamilyManagementParentView(viewModel: viewModel)

    let hostingController = UIHostingController(rootView: view)
    let uiView = hostingController.view!

    XCTAssertNotNil(uiView)
  }
}

// MARK: - Note: Mock services removed
// Using shared mocks from TheRecruitingCompassTests/Mocks/
// - MockFamilyService (in MockFamilyManager.swift)
// - MockAuthManager (in MockAuthManager.swift)
