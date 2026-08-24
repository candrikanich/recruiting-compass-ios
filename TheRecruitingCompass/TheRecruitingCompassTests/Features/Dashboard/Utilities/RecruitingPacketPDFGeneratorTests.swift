import XCTest
@testable import TheRecruitingCompass

@MainActor
final class RecruitingPacketPDFGeneratorTests: XCTestCase {

  private func makeData(schoolsInEachTier: Int = 2) -> RecruitingPacketData {
    func rows(_ status: String) -> [RecruitingPacketData.SchoolRow] {
      (0..<schoolsInEachTier).map { i in
        RecruitingPacketData.SchoolRow(
          name: "\(status) School \(i)",
          location: "City, ST",
          division: "D1",
          conference: "Conf",
          status: status
        )
      }
    }
    let athlete = RecruitingPacketData.Athlete(
      fullName: "Jordan Sample",
      email: "jordan@example.com",
      phone: "555-1212",
      height: "6'2\"",
      weight: "185 lbs",
      position: "3B/SS",
      batsThrows: "R/R",
      schoolName: "Central High",
      graduationYear: 2027,
      gpa: 3.85,
      satScore: 1200,
      actScore: 27,
      coreCourses: ["AP Calculus", "AP Physics"],
      videoLinks: [.init(label: "Hudl", url: "https://hudl.com/x")],
      socialMedia: [.init(platform: "Instagram", handle: "@jordan")]
    )
    return RecruitingPacketData(
      athlete: athlete,
      tiers: .init(tierA: rows("Offer"), tierB: rows("Visiting"), tierC: rows("Contacted")),
      activity: .init(totalSchools: 6, totalInteractions: 12, recentContact: .now,
                      emails: 5, calls: 3, camps: 1, visits: 2, other: 1)
    )
  }

  func testGenerate_producesNonEmptyPDF() {
    let data = RecruitingPacketPDFGenerator().generate(data: makeData(), photo: nil)
    XCTAssertFalse(data.isEmpty)
    // Every PDF begins with the "%PDF" magic bytes.
    let header = data.prefix(4)
    XCTAssertEqual(String(decoding: header, as: UTF8.self), "%PDF")
  }

  func testGenerate_handlesEmptyProfileAndSchools() {
    let empty = RecruitingPacketData(
      athlete: .init(fullName: nil, email: nil, phone: nil, height: nil, weight: nil,
                     position: nil, batsThrows: nil, schoolName: nil, graduationYear: nil,
                     gpa: nil, satScore: nil, actScore: nil, coreCourses: [],
                     videoLinks: [], socialMedia: []),
      tiers: .init(tierA: [], tierB: [], tierC: []),
      activity: .init(totalSchools: 0, totalInteractions: 0, recentContact: nil,
                      emails: 0, calls: 0, camps: 0, visits: 0, other: 0)
    )
    let data = RecruitingPacketPDFGenerator().generate(data: empty, photo: nil)
    XCTAssertFalse(data.isEmpty)
    XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "%PDF")
  }

  func testGenerate_manySchoolsPaginatesWithoutCrash() {
    // Enough rows to force a page break — exercises the ensureRoom pagination path.
    let data = RecruitingPacketPDFGenerator().generate(data: makeData(schoolsInEachTier: 40), photo: nil)
    XCTAssertFalse(data.isEmpty)
  }
}
