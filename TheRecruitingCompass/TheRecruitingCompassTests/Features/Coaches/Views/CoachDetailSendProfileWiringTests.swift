import XCTest

/// `CoachDetailView` builds its own view model, so a hosted behavioural test isn't possible without
/// network. `SendProfileLoadModifierTests` covers the reload behaviour; this pins that the screen applies it.
final class CoachDetailSendProfileWiringTests: XCTestCase {
    nonisolated deinit {}

    func testCoachDetailViewAppliesTheSendProfileLoadModifier() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let source = testFile
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("TheRecruitingCompass/Features/Coaches/Views/CoachDetailView.swift")

        let text = try String(contentsOf: source, encoding: .utf8)

        XCTAssertTrue(
            text.contains(".modifier(SendProfileLoadModifier(viewModel: sendProfileVM, coachId: coachId))"),
            "CoachDetailView must load Send Profile state through SendProfileLoadModifier"
        )
    }
}
