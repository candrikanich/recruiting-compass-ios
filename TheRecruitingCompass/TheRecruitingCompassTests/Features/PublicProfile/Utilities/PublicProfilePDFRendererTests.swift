import XCTest
import UIKit
@testable import TheRecruitingCompass

@MainActor
final class PublicProfilePDFRendererTests: XCTestCase {

  private func makeData(playerName: String = "Jordan Sample") -> PublicProfileData {
    PublicProfileData(
      playerName: playerName,
      photoUrl: nil,
      headerColor: .blue,
      bio: "Dedicated infielder with a strong bat.",
      academics: .init(gpa: 3.85, satScore: 1200, actScore: 27,
                       graduationYear: 2027, highSchool: "Central High",
                       intendedMajor: "Kinesiology",
                       coreCourses: ["AP Calculus", "AP Physics"]),
      credentials: .init(primarySport: "Baseball", primaryPosition: "Shortstop",
                      positions: ["Shortstop", "Third Base"], heightInches: 74,
                      weightLbs: 185, ncaaId: "1234567", perfectGameId: nil,
                      prepBaseballId: nil, prepBaseballState: nil),
      metrics: [.init(key: "exit_velo", label: "Exit Velocity", value: "88.0", unit: "mph", verified: true)],
      film: [.init(title: "2026 Highlights", url: "https://hudl.com/x")],
      lookingFor: "A program that values academics and athletics equally.",
      valuesTags: ["Academics", "Faith"],
      teamHistory: [.init(name: "Central HS Varsity", level: "12th Grade", coach: "Coach Lee", contact: nil, years: nil)],
      awards: [.init(title: "All-Conference", year: 2026)],
      social: .init(twitterHandle: "@jordan", instagramHandle: "@jordan",
                    tiktokHandle: nil, facebookUrl: nil),
      commitmentStatus: .uncommitted,
      committedSchoolName: nil,
      updatedAt: Date(timeIntervalSince1970: 1_754_784_000),
      visibleSectionOrder: DefaultSectionOrder.keys
    )
  }

  private let pdfMagic = Array("%PDF".utf8)

  func testRender_producesNonEmptyPDF() throws {
    let pdf = try XCTUnwrap(PublicProfilePDFRenderer.render(makeData()))
    XCTAssertFalse(pdf.isEmpty)
    XCTAssertTrue(pdf.starts(with: pdfMagic))
  }

  func testRender_minimalProfileStillRenders() throws {
    let minimal = PublicProfileData(
      playerName: "A", photoUrl: nil, headerColor: .slate, bio: nil,
      academics: nil, credentials: nil, metrics: nil, film: nil,
      lookingFor: nil, valuesTags: [], teamHistory: nil, awards: nil, social: nil,
      commitmentStatus: .uncommitted, committedSchoolName: nil, updatedAt: nil,
      visibleSectionOrder: []
    )
    let pdf = try XCTUnwrap(PublicProfilePDFRenderer.render(minimal))
    XCTAssertTrue(pdf.starts(with: pdfMagic))
  }

  func testRender_withInjectedPhotoStillRenders() throws {
    let photo = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { ctx in
      UIColor.blue.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
    }
    let pdf = try XCTUnwrap(PublicProfilePDFRenderer.render(makeData(), photo: photo))
    XCTAssertTrue(pdf.starts(with: pdfMagic))
  }

  func testLoadPhoto_invalidURLReturnsNil() async {
    let none = await PublicProfilePDFRenderer.loadPhoto(nil)
    XCTAssertNil(none)
    let bad = await PublicProfilePDFRenderer.loadPhoto("not a url")
    XCTAssertNil(bad)
  }

  func testFilename_sanitizesPlayerName() {
    XCTAssertEqual(PublicProfilePDFRenderer.filename(for: "Jordan Sample"), "Jordan_Sample_Profile.pdf")
    // Non-alphanumerics (apostrophe, hyphen) are stripped; spaces become underscores.
    XCTAssertEqual(PublicProfilePDFRenderer.filename(for: "O'Neil-Smith"), "ONeilSmith_Profile.pdf")
    XCTAssertEqual(PublicProfilePDFRenderer.filename(for: "   "), "Athlete_Profile.pdf")
  }
}
