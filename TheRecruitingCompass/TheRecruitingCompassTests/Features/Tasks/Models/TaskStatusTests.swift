import XCTest
@testable import TheRecruitingCompass

@MainActor
final class TaskStatusTests: XCTestCase {

  func testRawValue_NotStarted() {
    XCTAssertEqual(TaskStatus.notStarted.rawValue, "not_started")
  }

  func testRawValue_InProgress() {
    XCTAssertEqual(TaskStatus.inProgress.rawValue, "in_progress")
  }

  func testRawValue_Completed() {
    XCTAssertEqual(TaskStatus.completed.rawValue, "completed")
  }

  func testDisplayName_NotStarted() {
    XCTAssertEqual(TaskStatus.notStarted.displayName, "Not Started")
  }

  func testDisplayName_InProgress() {
    XCTAssertEqual(TaskStatus.inProgress.displayName, "In Progress")
  }

  func testDisplayName_Completed() {
    XCTAssertEqual(TaskStatus.completed.displayName, "Completed")
  }

  func testDecode_NotStarted() throws {
    let json = "\"not_started\""
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
    XCTAssertEqual(decoded, .notStarted)
  }

  func testDecode_InProgress() throws {
    let json = "\"in_progress\""
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
    XCTAssertEqual(decoded, .inProgress)
  }

  func testDecode_Completed() throws {
    let json = "\"completed\""
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
    XCTAssertEqual(decoded, .completed)
  }

  func testEncodeDecode_RoundTrip() throws {
    for status in TaskStatus.allCases {
      let data = try JSONEncoder().encode(status)
      let decoded = try JSONDecoder().decode(TaskStatus.self, from: data)
      XCTAssertEqual(decoded, status)
    }
  }
}
