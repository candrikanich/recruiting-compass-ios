import Foundation

/// First-run copy and rules, kept out of the views so tests can pin the wording. The strings match web
/// (`utils/firstRun.ts`, web#1536) word for word.
enum FirstRunCopy {
  static let intro =
    "The Recruiting Compass guides your family through recruiting: what to do next, with every school, "
    + "coach, and conversation in one place."

  static let playerSchoolPrompt = "Which school are you most excited about?"
  static let parentSchoolPrompt = "Which school is your athlete most excited about?"
  static let skipLabel = "Not sure yet"

  static func schoolPrompt(for role: UserRole?) -> String {
    role == .parent ? parentSchoolPrompt : playerSchoolPrompt
  }

  static func addedConfirmation(schoolName: String) -> String {
    "Added \(schoolName) to your favorites."
  }

  static let helpFirstSchool =
    "The last step of setup asks which school you're most excited about. Search for it and pick it, and it's "
    + "added to your list as a favorite. Parents are asked which school their athlete is most excited about, "
    + "even before the athlete has joined: the school waits on the family's list for them. "
    + "Everyone gets this step, whatever their age. Not sure yet? Tap Not sure yet. Nothing is marked "
    + "incomplete, and you can add schools any time from the Schools tab."

  static let helpDashboard =
    "The top of your dashboard shows the school you're most excited about and your next 1-3 steps for your "
    + "grade. Finish those first, and the rest of the dashboard fills in as you add schools, coaches, and "
    + "conversations."

  static let helpStatusScore =
    "Your status score appears once you've added a coach and logged a conversation. Until then there's "
    + "nothing to measure, so we don't show one."

  static let nextStepsUnavailable = "Couldn't load your next steps. Pull to refresh."

  /// The athlete already in the family, if any. A parent gets the school step either way (the school belongs
  /// to the family, so it is the athlete's once they join); this only decides whose recommendations to load.
  static func connectedAthlete(in members: [FamilyMember]) -> FamilyMember? {
    members.first(where: \.isAthlete)
  }

  // MARK: - Parent before the athlete joins (web#1540)

  static func pendingStepsHeading(athleteFirstName: String?) -> String {
    "Next steps for \(athleteFirstName ?? "your athlete")"
  }

  static func pendingStepsNote(athleteFirstName: String?) -> String {
    "\(athleteFirstName ?? "They") will see these, and the school you add, when they join. "
      + "They complete the steps themselves."
  }

  static let pendingTopSchoolLabel = "Top school so far: "

  static let helpParentBeforeAthlete =
    "If you sign up before your athlete does, you still get the first steps: the school you pick and the next "
    + "steps for your athlete's grade appear on your dashboard. You can read them but not complete them, because "
    + "your athlete does that themselves. When they join, they see the school and the steps too, and anything "
    + "they entered during their own signup is kept over what you entered."

  /// The pending-athlete card replaces the timeline card for a parent whose family has no athlete yet: that card
  /// reads the signed-in user's own timeline, which for a parent is not the athlete's. Waits for the family read
  /// so a parent whose athlete simply has not loaded yet never flashes it.
  static func showsPendingAthleteCard(isParent: Bool, membership: FamilyMembershipStatus, athleteCount: Int) -> Bool {
    isParent && membership == .member && athleteCount == 0
  }
}
