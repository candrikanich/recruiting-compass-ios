import XCTest
@testable import TheRecruitingCompass

final class HelpFamilyCopyTests: XCTestCase {
  private var allCopy: [String] {
    [
      HelpFamilyCopy.addingFamilyIntro, HelpFamilyCopy.everyAccountIntro, HelpFamilyCopy.createdForYou,
      HelpFamilyCopy.invitedJoin, HelpFamilyCopy.removedOrDeleted, HelpFamilyCopy.missingFamilyIntro,
      HelpFamilyCopy.stillLoading, HelpFamilyCopy.loadFailed, HelpFamilyCopy.noFamilyYet,
      HelpFamilyCopy.gettingStartedCallout
    ]
  }

  func test_familyIsCreatedAutomaticallyAtSignup() {
    XCTAssertTrue(HelpFamilyCopy.createdForYou.contains("created automatically"))
    XCTAssertTrue(HelpFamilyCopy.gettingStartedCallout.contains("created for you automatically"))
  }

  func test_addingFamilyIntroDoesNotRepeatTheCallout() {
    XCTAssertFalse(HelpFamilyCopy.addingFamilyIntro.contains("created automatically"))
  }

  func test_invitedUsersJoinTheExistingFamily() {
    XCTAssertTrue(HelpFamilyCopy.invitedJoin.contains("join their existing family"))
  }

  func test_removedUsersAreAskedToCreateOrJoinWithFamilyCode() {
    let text = HelpFamilyCopy.removedOrDeleted
    XCTAssertTrue(text.contains("create"))
    XCTAssertTrue(text.contains("Family Code"))
  }

  func test_stillLoadingQuotesTheMessageTheAppShows() {
    XCTAssertTrue(HelpFamilyCopy.stillLoading.contains(FamilyUnitID.MissingError.missing.errorDescription ?? "?"))
    XCTAssertTrue(HelpFamilyCopy.stillLoading.contains(CreateEventViewModel.familyNotLoadedMessage))
  }

  func test_onlyStillLoadingIsDescribedAsARefusedSave() {
    XCTAssertTrue(HelpFamilyCopy.stillLoading.contains("save is stopped"))
    XCTAssertFalse(HelpFamilyCopy.loadFailed.contains("save"))
    XCTAssertFalse(HelpFamilyCopy.noFamilyYet.contains("save"))
    XCTAssertTrue(HelpFamilyCopy.loadFailed.contains("when you open the app"))
    XCTAssertTrue(HelpFamilyCopy.noFamilyYet.contains("Family Code"))
  }

  func test_lastReviewedIsBumpedAndOldCopyIsGone() {
    XCTAssertEqual(HelpFamilyCopy.lastReviewed, "October 2026")
    XCTAssertTrue(HelpFamilyCopy.addingFamilyIntro.hasPrefix("Your family already exists"))
  }

  func test_noCoppaClaim() {
    for text in allCopy {
      XCTAssertFalse(text.localizedCaseInsensitiveContains("COPPA"), text)
    }
  }
}
