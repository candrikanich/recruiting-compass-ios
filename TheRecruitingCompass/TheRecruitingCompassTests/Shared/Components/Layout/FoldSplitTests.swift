// TheRecruitingCompass/TheRecruitingCompassTests/Shared/Components/Layout/FoldSplitTests.swift
import XCTest
@testable import TheRecruitingCompass

final class FoldSplitTests: XCTestCase {
  private let container = CGSize(width: 900, height: 1100)

  func testCenteredVerticalHingeSplitsColumnsAroundIt() throws {
    let hinge = CGRect(x: 430, y: 0, width: 40, height: 1100)

    let split = try XCTUnwrap(FoldSplit(divisionRegions: [hinge], containerSize: container))

    XCTAssertEqual(split, FoldSplit(leadingWidth: 430, gap: 40, trailingWidth: 430))
  }

  func testOffCenterHingeKeepsColumnWidthsSummingToContainer() throws {
    let hinge = CGRect(x: 350, y: -200, width: 30, height: 2000)

    let split = try XCTUnwrap(FoldSplit(divisionRegions: [hinge], containerSize: container))

    XCTAssertEqual(split.leadingWidth, 350)
    XCTAssertEqual(split.gap, 30)
    XCTAssertEqual(split.trailingWidth, 520)
    XCTAssertEqual(split.leadingWidth + split.gap + split.trailingWidth, container.width)
  }

  func testNoRegionsMeansNoSplit() {
    XCTAssertNil(FoldSplit(divisionRegions: [], containerSize: container))
  }

  func testHorizontalHingeIsIgnored() {
    let rotatedHinge = CGRect(x: 0, y: 530, width: 900, height: 40)

    XCTAssertNil(FoldSplit(divisionRegions: [rotatedHinge], containerSize: container))
  }

  func testHingeOutsideContainerIsIgnored() {
    let beyondTrailingEdge = CGRect(x: 950, y: 0, width: 40, height: 1100)
    let beforeLeadingEdge = CGRect(x: -60, y: 0, width: 40, height: 1100)

    XCTAssertNil(FoldSplit(divisionRegions: [beyondTrailingEdge], containerSize: container))
    XCTAssertNil(FoldSplit(divisionRegions: [beforeLeadingEdge], containerSize: container))
  }

  func testHingeLeavingTooNarrowAColumnIsIgnored() {
    let nearLeadingEdge = CGRect(x: 120, y: 0, width: 40, height: 1100)

    XCTAssertNil(FoldSplit(divisionRegions: [nearLeadingEdge], containerSize: container))
  }

  func testFirstUsableRegionWins() throws {
    let horizontal = CGRect(x: 0, y: 530, width: 900, height: 40)
    let vertical = CGRect(x: 430, y: 0, width: 40, height: 1100)

    let split = try XCTUnwrap(FoldSplit(divisionRegions: [horizontal, vertical], containerSize: container))

    XCTAssertEqual(split.leadingWidth, 430)
  }
}
