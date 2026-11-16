import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("FirstRunCopy — wording and rules shared with web#1536")
struct FirstRunCopyTests {

  private func member(role: String) -> FamilyMember {
    FamilyMember(
      id: "m-\(role)", userId: "u-\(role)", familyUnitId: "fam-1", role: role,
      addedAt: nil, user: nil, canRemove: nil, removeBlockedReason: nil
    )
  }

  @Test func introIsTheApprovedSentence() {
    #expect(
      FirstRunCopy.intro
        == "TRC guides your family through recruiting: what to do next, with every school, coach, "
        + "and conversation in one place."
    )
  }

  @Test func promptsLeadWithTheSchoolQuestion() {
    #expect(FirstRunCopy.schoolPrompt(for: .player) == "Which school are you most excited about?")
    #expect(FirstRunCopy.schoolPrompt(for: nil) == "Which school are you most excited about?")
    #expect(FirstRunCopy.schoolPrompt(for: .parent) == "Which school is your athlete most excited about?")
  }

  @Test func skipLabelIsNotSureYet() {
    #expect(FirstRunCopy.skipLabel == "Not sure yet")
  }

  @Test func parentWithNoAthleteGetsNoSchoolStep() {
    #expect(FirstRunCopy.connectedAthlete(in: []) == nil)
    #expect(FirstRunCopy.connectedAthlete(in: [member(role: "parent")]) == nil)
  }

  @Test func parentWithAConnectedAthleteGetsTheSchoolStep() {
    #expect(FirstRunCopy.connectedAthlete(in: [member(role: "parent"), member(role: "player")])?.userId == "u-player")
  }

  @Test func helpCenterExplainsTheSchoolStepAndSkip() {
    #expect(FirstRunCopy.helpFirstSchool.contains("which school you're most excited about"))
    #expect(FirstRunCopy.helpFirstSchool.contains("Not sure yet"))
    #expect(FirstRunCopy.helpFirstSchool.contains("favorite"))
  }
}
