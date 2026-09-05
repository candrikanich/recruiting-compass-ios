import XCTest
@testable import TheRecruitingCompass

final class DeadlineCategoryTests: XCTestCase {
  func test_allCasesHaveNonEmptyDisplayName() {
    for category in DeadlineCategory.allCases {
      XCTAssertFalse(category.displayName.isEmpty, "\(category) should have a display name")
    }
  }

  func test_allCasesHaveNonEmptyIcon() {
    for category in DeadlineCategory.allCases {
      XCTAssertFalse(category.icon.isEmpty, "\(category) should have an icon")
    }
  }

  func test_displayNames() {
    XCTAssertEqual(DeadlineCategory.application.displayName, "Application")
    XCTAssertEqual(DeadlineCategory.decision.displayName, "Decision")
    XCTAssertEqual(DeadlineCategory.financial_aid.displayName, "Financial Aid")
    XCTAssertEqual(DeadlineCategory.visit.displayName, "Visit")
    XCTAssertEqual(DeadlineCategory.custom.displayName, "Custom")
  }

  func test_rawValuesMatchDatabaseVocabulary() {
    XCTAssertEqual(DeadlineCategory.application.rawValue, "application")
    XCTAssertEqual(DeadlineCategory.decision.rawValue, "decision")
    XCTAssertEqual(DeadlineCategory.financial_aid.rawValue, "financial_aid")
    XCTAssertEqual(DeadlineCategory.visit.rawValue, "visit")
    XCTAssertEqual(DeadlineCategory.custom.rawValue, "custom")
  }

  func test_decodesFromRawJSONValue() throws {
    let json = "\"financial_aid\"".data(using: .utf8)!
    let decoded = try JSONDecoder().decode(DeadlineCategory.self, from: json)
    XCTAssertEqual(decoded, .financial_aid)
  }
}
