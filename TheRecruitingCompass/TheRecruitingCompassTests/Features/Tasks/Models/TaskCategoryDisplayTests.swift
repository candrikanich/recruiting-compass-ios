import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class TaskCategoryDisplayTests: XCTestCase {
  nonisolated deinit {}

  private func task(category: String) -> TaskWithStatus {
    TaskWithStatus(
      id: "1", title: "T", gradeLevel: 9, category: category, required: false,
      hasIncompletePrerequisites: false
    )
  }

  func testCategoryLabel_knownCategories_matchWebLabels() {
    XCTAssertEqual(task(category: "academic").categoryLabel, "Academic")
    XCTAssertEqual(task(category: "athletic").categoryLabel, "Athletic")
    XCTAssertEqual(task(category: "recruiting").categoryLabel, "Recruiting")
    XCTAssertEqual(task(category: "exposure").categoryLabel, "Exposure")
    XCTAssertEqual(task(category: "mindset").categoryLabel, "Mindset")
  }

  func testCategoryLabel_isCaseInsensitive() {
    XCTAssertEqual(task(category: "ACADEMIC").categoryLabel, "Academic")
    XCTAssertEqual(task(category: "Recruiting").categoryLabel, "Recruiting")
  }

  func testCategoryLabel_unknownCategory_capitalizesRawValue() {
    XCTAssertEqual(task(category: "custom").categoryLabel, "Custom")
  }

  func testCategoryColor_knownCategories_areDistinct() {
    let colors = ["academic", "athletic", "recruiting", "exposure", "mindset"]
      .map { task(category: $0).categoryColor }
    XCTAssertEqual(Set(colors.map(\.description)).count, colors.count)
  }
}
