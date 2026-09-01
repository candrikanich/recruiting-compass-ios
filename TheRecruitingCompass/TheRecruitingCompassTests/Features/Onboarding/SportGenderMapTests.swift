import Testing
@testable import TheRecruitingCompass

@Suite("SportGenderMap — sport-to-gender classification")
struct SportGenderMapTests {

  // MARK: - Male sports

  @Test func baseballIsMale() {
    #expect(SportGenderMap.gender(for: "Baseball") == .male)
  }

  @Test func footballIsMale() {
    #expect(SportGenderMap.gender(for: "Football") == .male)
  }

  @Test func wrestlingIsMale() {
    #expect(SportGenderMap.gender(for: "Wrestling") == .male)
  }

  // MARK: - Female sports

  @Test func softballIsFemale() {
    #expect(SportGenderMap.gender(for: "Softball") == .female)
  }

  @Test func fieldHockeyIsFemale() {
    #expect(SportGenderMap.gender(for: "Field Hockey") == .female)
  }

  @Test func volleyballIsFemale() {
    #expect(SportGenderMap.gender(for: "Volleyball") == .female)
  }

  @Test func beachVolleyballIsFemale() {
    #expect(SportGenderMap.gender(for: "Beach Volleyball") == .female)
  }

  // MARK: - Neutral / co-ed sports

  @Test func soccerIsNeutral() {
    #expect(SportGenderMap.gender(for: "Soccer") == .neutral)
  }

  @Test func basketballIsNeutral() {
    #expect(SportGenderMap.gender(for: "Basketball") == .neutral)
  }

  @Test func tennisIsNeutral() {
    #expect(SportGenderMap.gender(for: "Tennis") == .neutral)
  }

  @Test func lacrosseIsNeutral() {
    #expect(SportGenderMap.gender(for: "Lacrosse") == .neutral)
  }

  @Test func swimmingIsNeutral() {
    #expect(SportGenderMap.gender(for: "Swimming") == .neutral)
  }

  // MARK: - Unknown sport

  @Test func unknownSportReturnsNeutral() {
    #expect(SportGenderMap.gender(for: "Quidditch") == .neutral)
  }

  @Test func emptySportReturnsNeutral() {
    #expect(SportGenderMap.gender(for: "") == .neutral)
  }

  // MARK: - Whitespace trimming

  @Test func leadingWhitespaceTrimmed() {
    #expect(SportGenderMap.gender(for: "  Baseball") == .male)
  }

  @Test func trailingWhitespaceTrimmed() {
    #expect(SportGenderMap.gender(for: "Softball  ") == .female)
  }

  // MARK: - Case sensitivity (lookup is case-sensitive per implementation)

  @Test func lowercaseDoesNotMatch() {
    #expect(SportGenderMap.gender(for: "baseball") == .neutral)
  }

  // MARK: - genderRawValue mapping

  @Test func maleGenderRawValue() {
    #expect(SportGender.male.genderRawValue == Gender.male.rawValue)
  }

  @Test func femaleGenderRawValue() {
    #expect(SportGender.female.genderRawValue == Gender.female.rawValue)
  }

  @Test func neutralGenderRawValueIsNil() {
    #expect(SportGender.neutral.genderRawValue == nil)
  }
}
