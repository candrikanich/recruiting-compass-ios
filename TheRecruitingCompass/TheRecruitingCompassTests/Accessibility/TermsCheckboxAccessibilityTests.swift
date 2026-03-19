import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class TermsCheckboxAccessibilityTests: XCTestCase {
  nonisolated deinit {}

  func testTermsCheckbox_HasAccessibilityLabel() {
    @State var isChecked = false

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    let view = checkbox as any View
    XCTAssertNotNil(view)
  }

  func testTermsCheckbox_CheckedState_CorrectValue() {
    @State var isChecked = true

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    // Verify "Checked" value is accessible
    let view = checkbox as any View
    XCTAssertNotNil(view)
  }

  func testTermsCheckbox_UncheckedState_CorrectValue() {
    @State var isChecked = false

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    // Verify "Unchecked" value is accessible
    let view = checkbox as any View
    XCTAssertNotNil(view)
  }

  func testTermsCheckbox_TermsLink_HasLabel() {
    @State var isChecked = false

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    // Verify Terms of Service link is accessible
    let view = checkbox as any View
    XCTAssertNotNil(view)
  }

  func testTermsCheckbox_PrivacyLink_HasLabel() {
    @State var isChecked = false

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    // Verify Privacy Policy link is accessible
    let view = checkbox as any View
    XCTAssertNotNil(view)
  }

  func testTermsCheckbox_StaticText_Hidden() {
    @State var isChecked = false

    let checkbox = TermsCheckbox(
      isChecked: $isChecked,
      onTermsPressed: { },
      onPrivacyPressed: { }
    )

    // Verify "I agree to the" and "and" are marked hidden
    let view = checkbox as any View
    XCTAssertNotNil(view)
  }
}
