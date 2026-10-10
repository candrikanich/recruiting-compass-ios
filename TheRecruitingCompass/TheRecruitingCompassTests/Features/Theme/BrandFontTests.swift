import SwiftUI
import UIKit
import XCTest
@testable import TheRecruitingCompass

final class BrandFontTests: XCTestCase {
  private let allPostScriptNames = [
    "Barlow-Regular", "Barlow-Medium", "Barlow-SemiBold",
    "BarlowSemiCondensed-Medium", "BarlowSemiCondensed-SemiBold", "BarlowSemiCondensed-Bold"
  ]

  func test_bundledFonts_resolveInTestHost() {
    for name in allPostScriptNames {
      XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) must be bundled and registered in UIAppFonts")
    }
  }

  func test_everyStyleAndWeight_mapsToABundledFace() {
    let styles: [Font.TextStyle] = [
      .largeTitle, .title, .title2, .title3, .headline, .body, .callout, .subheadline, .footnote, .caption, .caption2
    ]
    let weights: [Font.Weight] = [.regular, .medium, .semibold, .bold]
    for style in styles {
      for weight in weights {
        let name = BrandFont.postScriptName(style, weight: weight)
        XCTAssertTrue(allPostScriptNames.contains(name), "\(style) \(weight) -> \(name)")
      }
    }
  }

  func test_displayFace_onlyForLargeStyles() {
    XCTAssertTrue(BrandFont.usesDisplayFace(.title2))
    XCTAssertFalse(BrandFont.usesDisplayFace(.headline))
    XCTAssertEqual(BrandFont.postScriptName(.title, weight: .bold), "BarlowSemiCondensed-Bold")
    XCTAssertEqual(BrandFont.postScriptName(.body, weight: .bold), "Barlow-SemiBold")
  }

  func test_headlineDefaultsToSemibold() {
    XCTAssertEqual(BrandFont.defaultWeight(.headline), .semibold)
    XCTAssertEqual(BrandFont.defaultWeight(.body), .regular)
  }

  func test_uiFont_scalesWithDynamicType() {
    let small = UITraitCollection(preferredContentSizeCategory: .small)
    let large = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraLarge)
    let body = BrandFont.uiFont(.body)
    XCTAssertGreaterThan(body.withSize(body.pointSize).pointSize, 0)
    let smallSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: small)
    let largeSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: large)
    XCTAssertGreaterThan(largeSize, smallSize)
  }
}
