import XCTest
@testable import TheRecruitingCompass

final class HelpFamilyCopyTests: XCTestCase {
  private var allCopy: [String] {
    [
      HelpFamilyCopy.addingFamilyIntro, HelpFamilyCopy.everyAccountIntro, HelpFamilyCopy.createdForYou,
      HelpFamilyCopy.invitedJoin, HelpFamilyCopy.removedOrDeleted, HelpFamilyCopy.saveRefusedIntro,
      HelpFamilyCopy.refusedStillLoading, HelpFamilyCopy.refusedLookupFailed, HelpFamilyCopy.refusedMissing
    ]
  }

  func test_familyIsCreatedAutomaticallyAtSignup() {
    XCTAssertTrue(HelpFamilyCopy.createdForYou.contains("created automatically"))
    XCTAssertTrue(HelpFamilyCopy.addingFamilyIntro.contains("created automatically"))
  }

  func test_invitedUsersJoinTheExistingFamily() {
    XCTAssertTrue(HelpFamilyCopy.invitedJoin.contains("join their existing family"))
  }

  func test_removedUsersAreAskedToCreateOrJoinWithFamilyCode() {
    let text = HelpFamilyCopy.removedOrDeleted
    XCTAssertTrue(text.contains("create"))
    XCTAssertTrue(text.contains("Family Code"))
  }

  func test_refusalMessagesMatchWhatTheAppShows() {
    XCTAssertEqual(HelpFamilyCopy.refusedStillLoading, FamilyUnitID.MissingError.missing.errorDescription)
    XCTAssertEqual(HelpFamilyCopy.refusedStillLoading, CreateEventViewModel.familyNotLoadedMessage)
    XCTAssertTrue(HelpFamilyCopy.refusedLookupFailed.contains("We couldn't load your family"))
    XCTAssertTrue(HelpFamilyCopy.refusedMissing.contains("Family Code"))
  }

  func test_lastReviewedIsBumpedAndOldCopyIsGone() {
    XCTAssertEqual(HelpFamilyCopy.lastReviewed, "October 2026")
    let oldIntro = "Parents and guardians can be added as family members to view and collaborate "
      + "on your recruiting journey."
    XCTAssertNotEqual(HelpFamilyCopy.addingFamilyIntro, oldIntro)
  }

  func test_noCoppaClaim() {
    for text in allCopy {
      XCTAssertFalse(text.localizedCaseInsensitiveContains("COPPA"), text)
    }
  }
}
