import XCTest
@testable import TheRecruitingCompass

/// Pure copy + channel-selection logic for Send Profile — no async, no services.
final class SendProfileCopyTests: XCTestCase {
    nonisolated deinit {}

    private let url = URL(string: "https://app.example.com/p/owen?ref=abcd1234")!

    // MARK: - Subject

    func testSubjectIncludesGradYearNameAndPositions() {
        let subject = SendProfileCopy.subject(
            playerName: "Owen Andrikanich", graduationYear: 2028, positions: "3B/2B"
        )
        XCTAssertEqual(subject, "2028 Owen Andrikanich Recruiting Profile (3B/2B)")
    }

    func testSubjectOmitsGradYearWhenMissing() {
        let subject = SendProfileCopy.subject(
            playerName: "Owen Andrikanich", graduationYear: nil, positions: "3B/2B"
        )
        XCTAssertEqual(subject, "Owen Andrikanich Recruiting Profile (3B/2B)")
    }

    func testSubjectOmitsPositionsWhenEmpty() {
        let subject = SendProfileCopy.subject(
            playerName: "Owen Andrikanich", graduationYear: 2028, positions: ""
        )
        XCTAssertEqual(subject, "2028 Owen Andrikanich Recruiting Profile")
    }

    // MARK: - Email body

    func testEmailBodyGreetsCoachByLastNameAndIncludesURL() {
        let body = SendProfileCopy.emailBody(
            playerName: "Owen Andrikanich", coachLastName: "Smith", url: url
        )
        XCTAssertTrue(body.hasPrefix("Hi Coach Smith,"), body)
        XCTAssertTrue(body.contains("Owen Andrikanich's recruiting profile"), body)
        XCTAssertTrue(body.contains(url.absoluteString), body)
    }

    func testEmailBodyFallsBackToGenericGreetingWhenLastNameBlank() {
        let body = SendProfileCopy.emailBody(
            playerName: "Owen Andrikanich", coachLastName: "  ", url: url
        )
        XCTAssertTrue(body.hasPrefix("Hi Coach,"), body)
    }

    // MARK: - Text body

    func testTextBodyIsShortAndIncludesURL() {
        let body = SendProfileCopy.textBody(
            playerName: "Owen Andrikanich", graduationYear: 2028, url: url
        )
        XCTAssertTrue(body.contains("2028 Owen Andrikanich"), body)
        XCTAssertTrue(body.contains(url.absoluteString), body)
    }

    // MARK: - Channel selection

    func testChannelEmailOnly() {
        XCTAssertEqual(SendProfileCopy.channel(email: "c@x.edu", phone: nil), .email)
    }

    func testChannelTextOnly() {
        XCTAssertEqual(SendProfileCopy.channel(email: nil, phone: "5551234"), .text)
    }

    func testChannelBoth() {
        XCTAssertEqual(SendProfileCopy.channel(email: "c@x.edu", phone: "5551234"), .both)
    }

    func testChannelNone() {
        XCTAssertEqual(SendProfileCopy.channel(email: nil, phone: nil), .none)
    }
}
