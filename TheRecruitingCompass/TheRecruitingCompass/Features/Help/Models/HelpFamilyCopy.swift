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

  static let missingFamilyIntro = "If your family can't be found, you'll see one of these:"

  static let stillLoading =
    "Still loading: a save is stopped with \"Your family account is still loading. Please wait a moment and try "
    + "again.\""

  static let loadFailed =
    "We couldn't load your family: a full screen with a Try again button when you open the app. Check your "
    + "connection and tap Try again. Your family is fine; the app couldn't reach it."

  static let noFamilyYet =
    "No family yet: a screen to create a family or join one with a Family Code appears when you open the app, "
    + "before you can make changes."

  static let gettingStartedCallout =
    "When you sign up, your family is created for you automatically. If someone invited you, you join their "
    + "family instead. See Account & Settings → Every account has a family."

  static let addingFamilyIntro =
    "Your family already exists from the moment you sign up. Parents and guardians can be added as family "
    + "members to view and collaborate on your recruiting journey."
}
