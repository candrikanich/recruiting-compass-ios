import XCTest
@testable import TheRecruitingCompass

final class VideoLinkURLFeedbackTests: XCTestCase {
  func test_emptyInput_noSaveNoMessage() {
    let feedback = VideoLinkURLFeedback(input: "")
    XCTAssertFalse(feedback.canSave)
    XCTAssertFalse(feedback.showsMessage)
  }

  func test_inputThatCanStillBecomeValid_disablesSaveWithoutMessage() {
    for typing in ["h", "HT", "http", "https:", "https:/", "http://", "https://"] {
      let feedback = VideoLinkURLFeedback(input: typing)
      XCTAssertFalse(feedback.canSave, typing)
      XCTAssertFalse(feedback.showsMessage, typing)
    }
  }

  func test_inputThatCanNeverBecomeValid_disablesSaveAndShowsMessage() {
    for bad in ["ftp://x", "javascript:alert(1)", "hudl.com/x", " https://hudl.com/x", "x"] {
      let feedback = VideoLinkURLFeedback(input: bad)
      XCTAssertFalse(feedback.canSave, bad)
      XCTAssertTrue(feedback.showsMessage, bad)
    }
  }

  func test_validInput_enablesSaveWithoutMessage() {
    for good in ["https://hudl.com/x", "HTTPS://youtu.be/x", "http://hudl.com/x", "https://hudl.com/x "] {
      let feedback = VideoLinkURLFeedback(input: good)
      XCTAssertTrue(feedback.canSave, good)
      XCTAssertFalse(feedback.showsMessage, good)
    }
  }
}
