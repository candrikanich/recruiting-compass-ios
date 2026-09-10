import XCTest
@testable import TheRecruitingCompass

final class NewCoachFormStateTests: XCTestCase {

  // MARK: - trimmedEmail

  func testTrimmedEmail_TrimsWhitespace() {
    var form = NewCoachFormState()
    form.email = "  coach@school.edu  "

    XCTAssertEqual(form.trimmedEmail, "coach@school.edu")
  }

  func testTrimmedEmail_EmptyWhenBlank() {
    let form = NewCoachFormState()

    XCTAssertEqual(form.trimmedEmail, "")
  }

  // MARK: - isValid unaffected by email (optional on both platforms)

  func testIsValid_TrueWithoutEmail_WhenNamesPresent() {
    var form = NewCoachFormState()
    form.firstName = "John"
    form.lastName = "Smith"

    XCTAssertTrue(form.isValid)
  }

  // MARK: - reset clears email

  func testReset_ClearsEmail() {
    var form = NewCoachFormState()
    form.email = "coach@school.edu"

    form.reset()

    XCTAssertEqual(form.email, "")
  }

  // MARK: - prefill(fromSenderName:) — parity w/ web's splitSenderName

  func testPrefillFromSenderName_SplitsFirstAndLast() {
    let (first, last) = NewCoachFormState.splitSenderName("Mark Royer")

    XCTAssertEqual(first, "Mark")
    XCTAssertEqual(last, "Royer")
  }

  func testPrefillFromSenderName_JoinsMultipleTrailingTokens() {
    let (first, last) = NewCoachFormState.splitSenderName("Mary Jane Watson")

    XCTAssertEqual(first, "Mary")
    XCTAssertEqual(last, "Jane Watson")
  }

  func testPrefillFromSenderName_SingleWord_LastNameBlank() {
    let (first, last) = NewCoachFormState.splitSenderName("Coach")

    XCTAssertEqual(first, "Coach")
    XCTAssertEqual(last, "")
  }

  func testPrefillFromSenderName_NilOrEmpty_BothBlank() {
    let (first1, last1) = NewCoachFormState.splitSenderName(nil)
    let (first2, last2) = NewCoachFormState.splitSenderName("")

    XCTAssertEqual(first1, "")
    XCTAssertEqual(last1, "")
    XCTAssertEqual(first2, "")
    XCTAssertEqual(last2, "")
  }
}
