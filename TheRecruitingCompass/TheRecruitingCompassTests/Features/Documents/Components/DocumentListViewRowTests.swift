import XCTest
import SwiftUI
@testable import TheRecruitingCompass

@MainActor
final class DocumentListViewRowTests: XCTestCase {
  nonisolated deinit {}

  private func makeDocument(title: String = "Transcript 2026") -> TheRecruitingCompass.Document {
    Document(
      id: "doc-1",
      userId: "user-1",
      type: .transcript,
      title: title,
      description: nil,
      fileUrl: "https://example.com/doc.pdf",
      fileType: "pdf",
      version: 1,
      schoolId: "school-1",
      isCurrent: true,
      sharedWithSchools: [],
      uploadedBy: "user-1",
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z"
    )
  }

  // MARK: - Delete Affordance
  // Regression: delete was reachable only via .swipeActions, inert inside
  // ScrollView+LazyVStack. The row now owns an explicit, labeled delete button.

  func testDeleteAccessibilityLabel() {
    let row = DocumentListViewRow(
      document: makeDocument(title: "Transcript 2026"),
      schoolName: "Stanford",
      onTap: {},
      onDelete: {}
    )

    XCTAssertEqual(row.deleteAccessibilityLabel, "Delete Transcript 2026")
  }

  func testOnDeleteClosureIsStored() {
    var deleted = false
    let row = DocumentListViewRow(
      document: makeDocument(),
      schoolName: "Stanford",
      onTap: {},
      onDelete: { deleted = true }
    )

    row.onDelete()

    XCTAssertTrue(deleted, "Delete button must invoke the supplied onDelete closure")
  }
}
