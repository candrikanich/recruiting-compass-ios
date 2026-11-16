import Foundation

/// First-run copy and rules, kept out of the views so tests can pin the wording. The strings match web
/// (`utils/firstRun.ts`, web#1536) word for word.
enum FirstRunCopy {
  static let intro =
    "TRC guides your family through recruiting: what to do next, with every school, coach, and conversation "
    + "in one place."

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
    + "added to your list as a favorite. Parents are asked which school their athlete is most excited about. "
    + "Everyone gets this step, whatever their age. Not sure yet? Tap Not sure yet. Nothing is marked "
    + "incomplete, and you can add schools any time from the Schools tab."

  /// A parent only gets the school step once an athlete has joined the family: until then there is nobody
  /// whose favorite this would be, and the write stays with #492.
  static func parentHasConnectedAthlete(members: [FamilyMember]) -> Bool {
    members.contains(where: \.isAthlete)
  }
}
