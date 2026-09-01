import Testing
@testable import TheRecruitingCompass

@Suite("PlayerDetails.topMissingFields — weight-ordered completeness")
struct ProfileCompletenessTests {

  private func makeDetails(
    gpa: Double? = nil,
    graduationYear: Int? = nil,
    primarySport: String? = nil,
    primaryPosition: String? = nil,
    satScore: Int? = nil,
    actScore: Int? = nil,
    phone: String? = nil,
    heightInches: Int? = nil,
    weightLbs: Int? = nil
  ) -> PlayerDetails {
    var d = PlayerDetails.default
    d.gpa = gpa
    d.graduationYear = graduationYear
    d.primarySport = primarySport
    d.primaryPosition = primaryPosition
    d.satScore = satScore
    d.actScore = actScore
    d.phone = phone
    d.heightInches = heightInches
    d.weightLbs = weightLbs
    return d
  }

  // MARK: - All fields present

  @Test func allFieldsPresentReturnsEmpty() {
    let details = makeDetails(
      gpa: 3.5,
      graduationYear: 2028,
      primarySport: "Baseball",
      primaryPosition: "Shortstop",
      satScore: 1200,
      phone: "555-1234",
      heightInches: 72,
      weightLbs: 185
    )
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: true)
    #expect(missing.isEmpty)
  }

  // MARK: - Missing GPA and SAT

  @Test func missingGPAAndSATReturnsThose() {
    let details = makeDetails(
      graduationYear: 2028,
      primarySport: "Baseball",
      primaryPosition: "Catcher",
      phone: "555-1234",
      heightInches: 72,
      weightLbs: 185
    )
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: true)
    let ids = missing.map(\.id)
    #expect(ids.contains("gpa"))
    #expect(ids.contains("testScores"))
  }

  // MARK: - Limit

  @Test func defaultLimitIs3() {
    let details = makeDetails() // everything nil
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: false)
    #expect(missing.count == 3)
  }

  @Test func customLimitRespected() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: false, limit: 5)
    #expect(missing.count == 5)
  }

  // MARK: - Weight ordering (GPA is highest weight)

  @Test func gpaIsFirstMissingField() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: false)
    #expect(missing.first?.id == "gpa")
  }

  // MARK: - External flags

  @Test func hasHighlightVideoExcludesVideoField() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: false, limit: 10)
    let ids = missing.map(\.id)
    #expect(!ids.contains("video"))
  }

  @Test func noHighlightVideoIncludesVideoField() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: false, limit: 10)
    let ids = missing.map(\.id)
    #expect(ids.contains("video"))
  }

  @Test func hasHomeLocationExcludesLocationField() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: true, limit: 10)
    let ids = missing.map(\.id)
    #expect(!ids.contains("location"))
  }

  // MARK: - Test scores: either SAT or ACT fills the gap

  @Test func havingSATOnlyExcludesTestScores() {
    let details = makeDetails(satScore: 1400)
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: true, limit: 10)
    let ids = missing.map(\.id)
    #expect(!ids.contains("testScores"))
  }

  @Test func havingACTOnlyExcludesTestScores() {
    let details = makeDetails(actScore: 32)
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: true, limit: 10)
    let ids = missing.map(\.id)
    #expect(!ids.contains("testScores"))
  }

  // MARK: - Whitespace-only sport treated as missing

  @Test func whitespaceSportIsMissing() {
    let details = makeDetails(primarySport: "   ")
    let missing = details.topMissingFields(hasHighlightVideo: true, hasHomeLocation: true, limit: 10)
    let ids = missing.map(\.id)
    #expect(ids.contains("sport"))
  }

  // MARK: - MissingField has icon and label

  @Test func missingFieldsHaveLabelsAndIcons() {
    let details = makeDetails()
    let missing = details.topMissingFields(hasHighlightVideo: false, hasHomeLocation: false, limit: 1)
    if let first = missing.first {
      #expect(!first.label.isEmpty)
      #expect(!first.icon.isEmpty)
    }
  }
}
