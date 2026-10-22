import Foundation

/// Help copy for "Every account has a family" (web `pages/help/family.vue`, web#1306). Kept out of the view so
/// tests can pin the wording. The refusal entries are the iOS equivalents of web's `requireFamilyId.ts`
/// messages: iOS has no refused-save for a missing family, because a signed-in user without one is held on the
/// create-or-join screen before reaching anything that saves.
enum HelpFamilyCopy {
  static let lastReviewed = "October 2026"

  static let sectionTitle = "Every account has a family"

  static let everyAccountIntro =
    "Every Recruiting Compass account belongs to a family, so players and parents work from one shared "
    + "recruiting plan."

  static let createdForYou = "Your family is created automatically when you sign up. There's nothing to set up."

  static let invitedJoin =
    "If a family member or guardian invited you, you join their existing family rather than starting a new one."

  static let removedOrDeleted =
    "The next time you open the app you'll be asked to create a new family or join one with a Family Code. "
    + "Your account stays, but schools, coaches, and tasks live in a family, so you'll need one to keep going."

  static let saveRefusedIntro =
    "Changes are saved to your family, so the app stops a save it can't attach to one:"

  static let refusedStillLoading = "Your family account is still loading. Please wait a moment and try again."

  static let refusedLookupFailed =
    "We couldn't load your family. Check your connection and tap Try again. Your family is fine; the app "
    + "couldn't reach it."

  static let refusedMissing =
    "You don't have a family yet. You'll see a screen to create one or join one with a Family Code before you "
    + "can make changes."

  static let addingFamilyIntro =
    "Your family is created automatically when you sign up. Parents and guardians can be added as family "
    + "members to view and collaborate on your recruiting journey."
}
