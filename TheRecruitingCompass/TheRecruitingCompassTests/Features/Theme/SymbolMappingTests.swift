import XCTest
@testable import TheRecruitingCompass

final class SymbolMappingTests: XCTestCase {
  func test_interestLevel_systemImage_matchesSpec() {
    XCTAssertEqual(InterestLevel.high.systemImage, "flame")
    XCTAssertEqual(InterestLevel.medium.systemImage, "bolt")
    XCTAssertEqual(InterestLevel.low.systemImage, "chart.line.downtrend.xyaxis")
    XCTAssertNil(InterestLevel.notSet.systemImage)
  }

  func test_notificationType_systemImage_matchesSpec() {
    XCTAssertEqual(NotificationType.followUpReminder.systemImage, "bell.fill")
    XCTAssertEqual(NotificationType.deadlineAlert.systemImage, "clock")
    XCTAssertEqual(NotificationType.weeklyDigest.systemImage, "chart.bar")
    XCTAssertEqual(NotificationType.inboundInteraction.systemImage, "envelope")
    XCTAssertEqual(NotificationType.offer.systemImage, "trophy")
    XCTAssertEqual(NotificationType.event.systemImage, "calendar")
    XCTAssertEqual(NotificationType.unknown.systemImage, "tray")
  }

  func test_reassuranceMessages_useSymbolNamesNotEmoji() {
    for message in ReassuranceMessage.all {
      XCTAssertTrue(message.systemImage.allSatisfy { $0.isASCII }, "\(message.id) icon must be an SF Symbol name")
    }
  }

  func test_documentType_systemImages_areAsciiSymbolNames() {
    for type in DocumentType.allCases {
      XCTAssertTrue(type.systemImage.allSatisfy { $0.isASCII }, "\(type) icon must be an SF Symbol name")
    }
  }
}
