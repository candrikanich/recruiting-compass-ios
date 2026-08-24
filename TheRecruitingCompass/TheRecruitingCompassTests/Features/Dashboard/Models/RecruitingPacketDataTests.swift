import XCTest
@testable import TheRecruitingCompass

final class RecruitingPacketDataTests: XCTestCase {

  // MARK: - Factories

  private func makeSchool(id: String = UUID().uuidString, status: String,
                          division: String? = "D1", conference: String? = "Big Ten",
                          city: String? = "Columbus", state: String? = "OH") throws -> School {
    var json: [String: Any] = [
      "id": id,
      "user_id": "u1",
      "name": "School \(id.prefix(4))",
      "status": status,
      "family_unit_id": "f1",
      "created_at": "2026-01-01T00:00:00Z",
      "updated_at": "2026-01-01T00:00:00Z",
      "city": city as Any,
      "state": state as Any
    ]
    if let division { json["division"] = division }
    if let conference { json["conference"] = conference }
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(School.self, from: data)
  }

  private func makeInteraction(type: String, occurredAt: String?) throws -> Interaction {
    var json: [String: Any] = [
      "id": UUID().uuidString,
      "type": type,
      "direction": "inbound",
      "family_unit_id": "f1",
      "created_at": "2026-01-01T00:00:00Z"
    ]
    if let occurredAt { json["occurred_at"] = occurredAt }
    let data = try JSONSerialization.data(withJSONObject: json)
    return try JSONDecoder().decode(Interaction.self, from: data)
  }

  // MARK: - Tier grouping

  func testGroupSchoolsByTier_bucketsByStatus() throws {
    let schools = [
      try makeSchool(status: "offer_received"),
      try makeSchool(status: "committed"),
      try makeSchool(status: "visiting"),
      try makeSchool(status: "contacted"),
      try makeSchool(status: "researching"),
      try makeSchool(status: "not_pursuing")
    ]

    let tiers = RecruitingPacketData.groupSchoolsByTier(schools)

    XCTAssertEqual(tiers.tierA.count, 2, "offer_received + committed → A")
    XCTAssertEqual(tiers.tierB.count, 1, "visiting → B")
    XCTAssertEqual(tiers.tierC.count, 3, "contacted + researching + not_pursuing → C")
  }

  func testGroupSchoolsByTier_deprecatedStatusFallsToTierC() throws {
    // Deprecated statuses are not 'visiting'/'offer_received'/'committed' → tier C, matching web.
    let schools = [
      try makeSchool(status: "camp_invite"),
      try makeSchool(status: "recruited")
    ]
    let tiers = RecruitingPacketData.groupSchoolsByTier(schools)
    XCTAssertTrue(tiers.tierA.isEmpty)
    XCTAssertTrue(tiers.tierB.isEmpty)
    XCTAssertEqual(tiers.tierC.count, 2)
  }

  func testSchoolRow_assemblesLocationAndStatusDisplay() throws {
    let school = try makeSchool(status: "offer_received", division: "D2",
                                conference: "SEC", city: "Austin", state: "TX")
    let row = RecruitingPacketData.schoolRow(school)
    XCTAssertEqual(row.location, "Austin, TX")
    XCTAssertEqual(row.division, "D2")
    XCTAssertEqual(row.conference, "SEC")
    XCTAssertEqual(row.status, "Offer Received")
  }

  func testSchoolRow_missingFieldsFallBackToDash() throws {
    let school = try makeSchool(status: "researching", division: nil,
                                conference: nil, city: nil, state: nil)
    let row = RecruitingPacketData.schoolRow(school)
    XCTAssertEqual(row.location, "—")
    XCTAssertEqual(row.division, "—")
    XCTAssertEqual(row.conference, "—")
  }

  // MARK: - Activity breakdown

  func testActivitySummary_bucketsInteractionTypes() throws {
    let interactions = [
      try makeInteraction(type: "email", occurredAt: "2026-02-01T00:00:00Z"),
      try makeInteraction(type: "email", occurredAt: "2026-02-02T00:00:00Z"),
      try makeInteraction(type: "phone_call", occurredAt: "2026-02-03T00:00:00Z"),
      try makeInteraction(type: "camp", occurredAt: "2026-02-04T00:00:00Z"),
      try makeInteraction(type: "showcase", occurredAt: "2026-02-05T00:00:00Z"),
      try makeInteraction(type: "in_person_visit", occurredAt: "2026-02-06T00:00:00Z"),
      try makeInteraction(type: "official_visit", occurredAt: "2026-02-07T00:00:00Z"),
      try makeInteraction(type: "virtual_meeting", occurredAt: "2026-02-08T00:00:00Z"),
      try makeInteraction(type: "unofficial_visit", occurredAt: "2026-02-09T00:00:00Z"),
      try makeInteraction(type: "text", occurredAt: "2026-02-10T00:00:00Z"),
      try makeInteraction(type: "game", occurredAt: "2026-02-11T00:00:00Z")
    ]

    let summary = RecruitingPacketData.activitySummary(schoolCount: 5, interactions: interactions)

    XCTAssertEqual(summary.totalSchools, 5)
    XCTAssertEqual(summary.totalInteractions, 11)
    XCTAssertEqual(summary.emails, 2)
    XCTAssertEqual(summary.calls, 1)
    XCTAssertEqual(summary.camps, 2, "camp + showcase")
    XCTAssertEqual(summary.visits, 4, "in_person + official + virtual + unofficial")
    XCTAssertEqual(summary.other, 2, "text + game")
  }

  func testActivitySummary_recentContactIsLatest() throws {
    let interactions = [
      try makeInteraction(type: "email", occurredAt: "2026-02-01T00:00:00Z"),
      try makeInteraction(type: "email", occurredAt: "2026-03-15T00:00:00Z"),
      try makeInteraction(type: "email", occurredAt: "2026-01-20T00:00:00Z")
    ]
    let summary = RecruitingPacketData.activitySummary(schoolCount: 0, interactions: interactions)
    let expected = Interaction.iso8601FallbackFormatter.date(from: "2026-03-15T00:00:00Z")
    XCTAssertEqual(summary.recentContact, expected)
  }

  func testActivitySummary_emptyHasNilRecentContact() {
    let summary = RecruitingPacketData.activitySummary(schoolCount: 0, interactions: [])
    XCTAssertNil(summary.recentContact)
    XCTAssertEqual(summary.totalInteractions, 0)
  }

  // MARK: - Bats/Throws + social

  func testBatsThrows_bothPresent() {
    XCTAssertEqual(RecruitingPacketData.batsThrows(bats: "R", throws: "R"), "R/R")
    XCTAssertEqual(RecruitingPacketData.batsThrows(bats: "L", throws: "R"), "L/R")
  }

  func testBatsThrows_oneMissingDegrades() {
    XCTAssertEqual(RecruitingPacketData.batsThrows(bats: "R", throws: nil), "R/—")
    XCTAssertEqual(RecruitingPacketData.batsThrows(bats: "", throws: "L"), "—/L")
  }

  func testBatsThrows_bothMissingIsNil() {
    XCTAssertNil(RecruitingPacketData.batsThrows(bats: nil, throws: nil))
    XCTAssertNil(RecruitingPacketData.batsThrows(bats: "  ", throws: ""))
  }

  func testSocialEntries_skipsEmpty() {
    let entries = RecruitingPacketData.socialEntries(instagram: "@ig", twitter: nil, tiktok: "  ")
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries.first?.platform, "Instagram")
    XCTAssertEqual(entries.first?.handle, "@ig")
  }
}
