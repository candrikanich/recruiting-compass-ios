import XCTest
@testable import TheRecruitingCompass

final class ProfileServiceDateOfBirthErrorTests: XCTestCase {
  private func error(_ json: String) -> ProfileServiceError? {
    ProfileServiceImpl.dateOfBirthError(from: Data(json.utf8))
  }

  func test_fieldErrors_dateOfBirth_usesFirstServerMessage() {
    let result = error(#"""
    {"statusMessage":"Invalid profile data","data":{"fieldErrors":{"date_of_birth":["Confirm first.","other"]}}}
    """#)
    guard case .dateOfBirth(let message) = result else { return XCTFail("expected dateOfBirth") }
    XCTAssertEqual(message, "Confirm first.")
  }

  func test_lockedForMinor403_usesStatusMessage() {
    let result = error(#"""
    {"statusCode":403,"statusMessage":"Your date of birth is locked.","data":{"code":"date_of_birth_locked_for_minor"}}
    """#)
    guard case .dateOfBirth(let message) = result else { return XCTFail("expected dateOfBirth") }
    XCTAssertEqual(message, "Your date of birth is locked.")
  }

  func test_otherFieldErrorsOrBodies_areNotDateOfBirthErrors() {
    XCTAssertNil(error(#"{"statusMessage":"Invalid profile data","data":{"fieldErrors":{"full_name":["bad"]}}}"#))
    XCTAssertNil(error("<html>bad gateway</html>"))
    XCTAssertNil(error(#"{"statusMessage":"Nope","data":{"code":"other"}}"#))
  }
}
