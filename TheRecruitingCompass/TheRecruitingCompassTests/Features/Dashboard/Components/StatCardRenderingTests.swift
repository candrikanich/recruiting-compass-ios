import SwiftUI
import UIKit
import XCTest
@testable import TheRecruitingCompass

/// Renders the real StatCard and checks painted pixels, so a dropped border, chip fill or icon tint goes red.
@MainActor
final class StatCardRenderingTests: XCTestCase {
  private struct Pixels {
    let width: Int
    let height: Int
    let data: [UInt8]
    func rgb(_ x: Int, _ y: Int) -> [Double] {
      let i = (y * width + x) * 4
      return [Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255]
    }
  }

  private func render(_ metric: StatMetric, dark: Bool) throws -> Pixels {
    let card = StatCard(title: "Coaches", count: 5, icon: "person.2", metric: metric, isEnabled: true, destination: nil)
      .frame(width: 180)
      .environment(\.colorScheme, dark ? .dark : .light)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 2
    let cgImage = try XCTUnwrap(renderer.cgImage)
    var data = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
    let context = try XCTUnwrap(CGContext(
      data: &data, width: cgImage.width, height: cgImage.height, bitsPerComponent: 8,
      bytesPerRow: cgImage.width * 4, space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return Pixels(width: cgImage.width, height: cgImage.height, data: data)
  }

  private func components(_ color: Color, dark: Bool) -> [Double] {
    let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    UIColor(color).resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return [Double(red), Double(green), Double(blue)]
  }

  private func isNear(_ pixel: [Double], _ target: [Double]) -> Bool {
    zip(pixel, target).allSatisfy { abs($0 - $1) < 0.04 }
  }

  private func count(_ pixels: Pixels, near target: [Double]) -> Int {
    var total = 0
    for y in 0..<pixels.height {
      for x in 0..<pixels.width where isNear(pixels.rgb(x, y), target) { total += 1 }
    }
    return total
  }

  func test_topBorder_isPaintedInAccentColor_forEveryMetricAndAppearance() throws {
    for metric in [StatMetric.coaches, .interactions] {
      for dark in [false, true] {
        let pixels = try render(metric, dark: dark)
        let expected = components(metric.accent.border, dark: dark)
        // Row 2 (1 pt down) at the horizontal middle sits inside the 3 pt border, clear of the rounded corners.
        XCTAssertTrue(isNear(pixels.rgb(pixels.width / 2, 2), expected), "\(metric) border dark=\(dark)")
      }
    }
  }

  func test_iconChip_isFilledWithAccentChipColor() throws {
    for metric in [StatMetric.coaches, .interactions] {
      for dark in [false, true] {
        let pixels = try render(metric, dark: dark)
        let chipPixels = count(pixels, near: components(metric.accent.chipFill, dark: dark))
        XCTAssertGreaterThan(chipPixels, 800, "\(metric) chip dark=\(dark)")
      }
    }
  }

  func test_icon_isTintedInAccentIconColor() throws {
    for metric in [StatMetric.coaches, .interactions] {
      for dark in [false, true] {
        let pixels = try render(metric, dark: dark)
        let iconPixels = count(pixels, near: components(metric.accent.icon, dark: dark))
        XCTAssertGreaterThan(iconPixels, 40, "\(metric) icon dark=\(dark)")
      }
    }
  }
}
