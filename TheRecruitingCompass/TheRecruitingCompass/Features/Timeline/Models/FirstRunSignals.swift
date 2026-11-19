import Foundation

/// What the first Home screen needs beyond the timeline endpoints, counted for the whole family (never just the
/// signed-in user) so a parent and the athlete agree on what is shown. Mirrors web's `useStatusScoreEligibility`.
struct FirstRunSignals: Equatable, Sendable {
  let coachCount: Int
  let conversationCount: Int
  let favoriteSchoolName: String?

  /// A brand-new account scores 8 ("at risk") before the family has done anything, so the number stays hidden
  /// until there is at least one coach and one logged conversation behind it. Display rule only: the status
  /// endpoint is untouched because shipped builds read it.
  var isStatusScoreVisible: Bool {
    coachCount >= 1 && conversationCount >= 1
  }
}
