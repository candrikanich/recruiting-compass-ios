import Testing
import Foundation
@testable import TheRecruitingCompass

@Suite("NuxProgress — pure model logic")
struct NuxProgressTests {

  // MARK: - NuxProgress.empty

  @Test func emptyProgressHasVersion1() {
    let progress = NuxProgress.empty
    #expect(progress.version == 1)
  }

  @Test func emptyProgressHasNoChecklistItems() {
    let progress = NuxProgress.empty
    #expect(progress.checklist.items.isEmpty)
  }

  @Test func emptyProgressHasNoDismissals() {
    let progress = NuxProgress.empty
    #expect(progress.dismissals.isEmpty)
  }

  @Test func emptyProgressHasNoFirstVisits() {
    let progress = NuxProgress.empty
    #expect(progress.firstVisits.isEmpty)
  }

  @Test func emptyProgressChecklistNotDismissed() {
    let progress = NuxProgress.empty
    #expect(progress.checklist.dismissedAt == nil)
  }

  // MARK: - completeItem

  @Test func completeItemMarksItemCompleted() {
    var progress = NuxProgress.empty
    progress.completeItem(.sport)
    #expect(progress.isItemCompleted(.sport))
  }

  @Test func completeItemSetsTimestamp() {
    var progress = NuxProgress.empty
    let before = Date()
    progress.completeItem(.sport)
    let item = progress.checklist.items[NuxChecklistKey.sport.rawValue]
    #expect(item != nil)
    #expect(item?.completed == true)
    #expect(item?.completedAt != nil)
    if let completedAt = item?.completedAt {
      #expect(completedAt >= before)
    }
  }

  @Test func completeItemIsIdempotent() {
    var progress = NuxProgress.empty
    progress.completeItem(.sport)
    let firstTimestamp = progress.checklist.items[NuxChecklistKey.sport.rawValue]?.completedAt

    progress.completeItem(.sport)
    let secondTimestamp = progress.checklist.items[NuxChecklistKey.sport.rawValue]?.completedAt

    #expect(firstTimestamp == secondTimestamp)
  }

  @Test func completeItemDoesNotAffectOtherItems() {
    var progress = NuxProgress.empty
    progress.completeItem(.sport)
    #expect(!progress.isItemCompleted(.firstSchool))
    #expect(!progress.isItemCompleted(.academics))
  }

  // MARK: - isItemCompleted

  @Test func isItemCompletedReturnsFalseForIncomplete() {
    let progress = NuxProgress.empty
    #expect(!progress.isItemCompleted(.sport))
    #expect(!progress.isItemCompleted(.firstSchool))
  }

  @Test func isItemCompletedReturnsTrueAfterCompletion() {
    var progress = NuxProgress.empty
    progress.completeItem(.firstCoach)
    #expect(progress.isItemCompleted(.firstCoach))
  }

  // MARK: - Checklist computations

  @Test func completedCountStartsAtZero() {
    let progress = NuxProgress.empty
    #expect(progress.checklist.completedCount == 0)
  }

  @Test func completedCountIncrements() {
    var progress = NuxProgress.empty
    progress.completeItem(.sport)
    #expect(progress.checklist.completedCount == 1)
    progress.completeItem(.firstSchool)
    #expect(progress.checklist.completedCount == 2)
  }

  @Test func percentageIsZeroWhenEmpty() {
    let progress = NuxProgress.empty
    #expect(progress.checklist.percentage == 0)
  }

  @Test func percentageIsCorrectAtHalfway() {
    var progress = NuxProgress.empty
    let halfCount = NuxChecklistKey.allCases.count / 2
    for key in NuxChecklistKey.allCases.prefix(halfCount) {
      progress.completeItem(key)
    }
    #expect(progress.checklist.percentage == Int((Double(halfCount) / Double(NuxChecklistKey.allCases.count) * 100).rounded()))
  }

  @Test func percentageIs100WhenAllComplete() {
    var progress = NuxProgress.empty
    for key in NuxChecklistKey.allCases {
      progress.completeItem(key)
    }
    #expect(progress.checklist.completedCount == NuxChecklistKey.allCases.count)
    #expect(progress.checklist.percentage == 100)
  }

  // MARK: - isPromptDismissed

  @Test func isPromptDismissedReturnsFalseWhenNoDismissal() {
    let progress = NuxProgress.empty
    #expect(!progress.isPromptDismissed("test_prompt", cooldownDays: 7))
  }

  @Test func isPromptDismissedReturnsTrueWithinCooldown() {
    var progress = NuxProgress.empty
    progress.dismissPrompt("test_prompt")
    #expect(progress.isPromptDismissed("test_prompt", cooldownDays: 7))
  }

  @Test func isPromptDismissedReturnsFalseAfterCooldownExpires() {
    var progress = NuxProgress.empty
    let eightDaysAgo = Date().addingTimeInterval(-8 * 86_400)
    progress.dismissals["test_prompt"] = eightDaysAgo
    #expect(!progress.isPromptDismissed("test_prompt", cooldownDays: 7))
  }

  @Test func isPromptDismissedExactBoundary() {
    var progress = NuxProgress.empty
    let exactlySevenDaysAgo = Date().addingTimeInterval(-7 * 86_400 - 1)
    progress.dismissals["test_prompt"] = exactlySevenDaysAgo
    #expect(!progress.isPromptDismissed("test_prompt", cooldownDays: 7))
  }

  // MARK: - dismissPrompt

  @Test func dismissPromptRecordsCurrentDate() {
    var progress = NuxProgress.empty
    let before = Date()
    progress.dismissPrompt("invite_prompt")
    let recorded = progress.dismissals["invite_prompt"]
    #expect(recorded != nil)
    if let recorded {
      #expect(recorded >= before)
    }
  }

  @Test func dismissPromptOverwritesPreviousDismissal() {
    var progress = NuxProgress.empty
    let oldDate = Date().addingTimeInterval(-86_400 * 30)
    progress.dismissals["invite_prompt"] = oldDate
    progress.dismissPrompt("invite_prompt")
    #expect(progress.dismissals["invite_prompt"]! > oldDate)
  }

  // MARK: - Codable round-trip

  @Test func codableRoundTrip() throws {
    var progress = NuxProgress.empty
    progress.completeItem(.sport)
    progress.completeItem(.firstSchool)
    progress.dismissPrompt("checklist")
    progress.firstVisits["dashboard"] = Date()

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(progress)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(NuxProgress.self, from: data)

    #expect(decoded.version == progress.version)
    #expect(decoded.isItemCompleted(.sport))
    #expect(decoded.isItemCompleted(.firstSchool))
    #expect(!decoded.isItemCompleted(.academics))
    #expect(decoded.dismissals["checklist"] != nil)
    #expect(decoded.firstVisits["dashboard"] != nil)
    #expect(decoded.checklist.completedCount == 2)
  }

  // MARK: - NuxChecklistKey.allCases count

  @Test func checklistKeyCountIs8() {
    #expect(NuxChecklistKey.allCases.count == 8)
  }

  // MARK: - NuxChecklistItem.incomplete

  @Test func incompleteItemIsNotCompleted() {
    let item = NuxChecklistItem.incomplete
    #expect(!item.completed)
    #expect(item.completedAt == nil)
  }
}
