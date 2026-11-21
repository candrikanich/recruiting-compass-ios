import SwiftUI
import UIKit
import XCTest
@testable import TheRecruitingCompass

final class StatAccentTests: XCTestCase {

  private let light = UITraitCollection(userInterfaceStyle: .light)
  private let dark = UITraitCollection(userInterfaceStyle: .dark)

  // MARK: - Metric to accent mapping (parity with web#1522 / ios#484)

  func test_coachesAndSchools_areForest() {
    XCTAssertEqual(StatMetric.coaches.accent, .forest)
    XCTAssertEqual(StatMetric.schools.accent, .forest)
  }

  func test_interactionsAndEvents_areGold() {
    XCTAssertEqual(StatMetric.interactions.accent, .gold)
    XCTAssertEqual(StatMetric.events.accent, .gold)
  }

  // MARK: - Colors come from brand tokens

  func test_forest_usesBrandTokens() {
    assertColor(StatAccent.forest.border, light: Color.Brand.forest600, dark: Color.Brand.forest400)
    assertColor(StatAccent.forest.chipFill, light: Color.Brand.forest100, dark: Color.Brand.forest900)
    assertColor(StatAccent.forest.icon, light: Color.Brand.forest700, dark: Color.Brand.forest200)
  }

  func test_gold_usesBrandTokens() {
    assertColor(StatAccent.gold.border, light: Color.Brand.gold600, dark: Color.Brand.gold400)
    assertColor(StatAccent.gold.chipFill, light: Color.Brand.gold100, dark: Color.Brand.gold900)
    assertColor(StatAccent.gold.icon, light: Color.Brand.gold700, dark: Color.Brand.gold200)
  }

  // MARK: - WCAG AA in both appearances

  func test_iconOnChip_meetsAAText_inLightAndDark() {
    for accent in StatAccent.allCases {
      for traits in [light, dark] {
        let ratio = contrast(accent.icon, accent.chipFill, traits)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(accent) icon on chip \(traits.userInterfaceStyle.rawValue)")
      }
    }
  }

  func test_borderOnCard_meetsAANonText_inLightAndDark() {
    for accent in StatAccent.allCases {
      for traits in [light, dark] {
        let ratio = contrast(accent.border, Color.Surface.card, traits)
        XCTAssertGreaterThanOrEqual(ratio, 3.0, "\(accent) border on card \(traits.userInterfaceStyle.rawValue)")
      }
    }
  }

  // MARK: - Helpers

  private func rgba(_ color: Color, _ traits: UITraitCollection) -> [CGFloat] {
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [red, green, blue, alpha]
  }

  private func assertColor(
    _ actual: Color, light expectedLight: Color, dark expectedDark: Color,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    for (traits, expected) in [(light, expectedLight), (dark, expectedDark)] {
      let actualRGBA = rgba(actual, traits), expectedRGBA = rgba(expected, traits)
      for channel in 0..<4 {
        XCTAssertEqual(
          actualRGBA[channel], expectedRGBA[channel], accuracy: 0.002,
          "\(traits.userInterfaceStyle.rawValue)", file: file, line: line
        )
      }
    }
  }

  private func luminance(_ color: Color, _ traits: UITraitCollection) -> Double {
    let linear = rgba(color, traits).prefix(3).map { channel -> Double in
      let value = Double(channel)
      return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
  }

  private func contrast(_ first: Color, _ second: Color, _ traits: UITraitCollection) -> Double {
    let lumFirst = luminance(first, traits), lumSecond = luminance(second, traits)
    return (max(lumFirst, lumSecond) + 0.05) / (min(lumFirst, lumSecond) + 0.05)
  }
}
