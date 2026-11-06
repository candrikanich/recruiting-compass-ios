import XCTest
@testable import TheRecruitingCompass

/// What the shared status components say to VoiceOver, and how long a toast stays up (#254).
final class StatusAnnouncementTests: XCTestCase {

  // MARK: - Toast

  func test_toastAnnouncement_success_isTheMessage() {
    XCTAssertEqual(ToastType.success.announcement(for: "Offer deleted"), "Offer deleted")
  }

  func test_toastAnnouncement_info_isTheMessage() {
    XCTAssertEqual(ToastType.info.announcement(for: "New coach added"), "New coach added")
  }

  func test_toastAnnouncement_error_saysItIsAnError() {
    // The type is otherwise carried only by a hidden icon.
    XCTAssertEqual(ToastType.error.announcement(for: "Failed to delete coach"), "Error: Failed to delete coach")
  }

  func test_toastAnnouncement_warning_saysItIsAWarning() {
    XCTAssertEqual(ToastType.warning.announcement(for: "Opening Mail instead"), "Warning: Opening Mail instead")
  }

  func test_toastAutoDismiss_withoutAssistiveTechnology_usesTheDuration() {
    XCTAssertEqual(ToastModifier.autoDismissDelay(duration: 3, assistiveTechnologyRunning: false), 3)
  }

  func test_toastAutoDismiss_withAssistiveTechnology_staysUntilDismissed() {
    XCTAssertNil(ToastModifier.autoDismissDelay(duration: 3, assistiveTechnologyRunning: true))
  }

  // MARK: - Save status

  func test_saveStatusAnnouncement_saved_isAnnounced() {
    XCTAssertEqual(SaveStatus.saved.announcement, "Changes saved")
  }

  func test_saveStatusAnnouncement_idleAndSaving_areSilent() {
    XCTAssertNil(SaveStatus.idle.announcement)
    XCTAssertNil(SaveStatus.saving.announcement)
  }

  // MARK: - Form error summary

  func test_formErrorAnnouncement_noErrors_isSilent() {
    XCTAssertNil(FormErrorSummary.announcement(for: []))
  }

  func test_formErrorAnnouncement_oneError_isSingular() {
    XCTAssertEqual(FormErrorSummary.announcement(for: ["First name is required"]), "1 error: First name is required")
  }

  func test_formErrorAnnouncement_severalErrors_listsThemAll() {
    XCTAssertEqual(
      FormErrorSummary.announcement(for: ["First name is required", "Invalid email"]),
      "2 errors: First name is required. Invalid email"
    )
  }
}
