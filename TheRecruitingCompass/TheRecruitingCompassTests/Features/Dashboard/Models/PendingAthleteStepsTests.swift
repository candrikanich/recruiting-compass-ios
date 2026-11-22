import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("PendingAthleteSteps: next steps for an athlete who has not joined (web#1540)")
struct PendingAthleteStepsTests {

  private let november2026 = Date(timeIntervalSince1970: 1_795_000_000)

  @Test func noStagedGraduationYearMeansNoGradeNeverADefault() {
    #expect(PendingAthleteSteps.grade(graduationYear: nil, referenceDate: november2026) == nil)
  }

  @Test func gradeComesFromTheStagedGraduationYear() {
    #expect(PendingAthleteSteps.grade(graduationYear: 2028, referenceDate: november2026) == 11)
    #expect(PendingAthleteSteps.grade(graduationYear: 2027, referenceDate: november2026) == 12)
  }

  @Test func onlyTheGradesTasksAreUsed() {
    let catalog = [TaskRow.stub(id: "a", grade: 11), TaskRow.stub(id: "b", grade: 10), TaskRow.stub(id: "c", grade: 12)]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["a"])
  }

  @Test func optionalTasksAreLeftOut() {
    let catalog = [TaskRow.stub(id: "a", required: false), TaskRow.stub(id: "b")]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["b"])
  }

  @Test func tasksWithNothingToSayAboutWhyTheyMatterAreLeftOut() {
    let catalog = [TaskRow.stub(id: "a", why: nil), TaskRow.stub(id: "b", why: ""), TaskRow.stub(id: "c")]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["c"])
  }

  @Test func higherPriorityCategoriesComeFirst() {
    let catalog = [
      TaskRow.stub(id: "m", category: "mindset"), TaskRow.stub(id: "e", category: "exposure"),
      TaskRow.stub(id: "t", category: "athletic")
    ]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["t", "e", "m"])
  }

  @Test func recruitingOutranksAthleticAndAcademicOutranksRecruiting() {
    let catalog = [
      TaskRow.stub(id: "t", category: "athletic"), TaskRow.stub(id: "r", category: "recruiting"),
      TaskRow.stub(id: "a", category: "academic")
    ]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["a", "r", "t"])
  }

  @Test func aTaskWithDependenciesGetsTwoExtraPoints() {
    // exposure 7 + 2 = 9 beats athletic 8; no dependencies would put it second.
    let catalog = [
      TaskRow.stub(id: "t", category: "athletic"),
      TaskRow.stub(id: "e", category: "exposure", dependencies: ["x"])
    ]
    let steps = PendingAthleteSteps.steps(from: catalog, grade: 11)
    #expect(steps.map(\.taskId) == ["e", "t"])
    #expect(steps.first?.priority == 9)
  }

  @Test func emptyDependencyListAddsNothing() {
    let steps = PendingAthleteSteps.steps(from: [TaskRow.stub(id: "e", category: "exposure", dependencies: [])], grade: 11)
    #expect(steps.first?.priority == 7)
  }

  @Test func unknownCategoriesCountAsFive() {
    let steps = PendingAthleteSteps.steps(from: [TaskRow.stub(id: "u", category: "other")], grade: 11)
    #expect(steps.first?.priority == 5)
  }

  @Test func aPriorityTieIsBrokenByTaskIdSoWebAndIosAgree() {
    let catalog = [TaskRow.stub(id: "b"), TaskRow.stub(id: "a"), TaskRow.stub(id: "c")]
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).map(\.taskId) == ["a", "b", "c"])
  }

  @Test func atMostThreeStepsAreShown() {
    let catalog = ["a", "b", "c", "d", "e"].map { TaskRow.stub(id: $0) }
    #expect(PendingAthleteSteps.steps(from: catalog, grade: 11).count == 3)
  }

  @Test func theTitleAndReasonCarryThroughAndNothingReadsAsDone() {
    let step = PendingAthleteSteps.steps(from: [TaskRow.stub(id: "a", why: "Do it early.")], grade: 11)[0]
    #expect(step.title == "Task a")
    #expect(step.whyItMatters == "Do it early.")
    #expect(step.isRequired)
  }
}
