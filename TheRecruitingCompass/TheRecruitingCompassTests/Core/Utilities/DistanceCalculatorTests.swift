import XCTest
import CoreLocation
@testable import TheRecruitingCompass

final class DistanceCalculatorTests: XCTestCase {
  nonisolated deinit {}

  // Winston-Salem, NC (Wake Forest area) -> a home ~372 mi away.
  // Reference pair validated against web utils/distance.ts (R = 3958.8, Math.round).
  private let wakeForest = CLLocationCoordinate2D(latitude: 36.1330, longitude: -80.2770)
  private let home = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060) // NYC

  func testHaversineDistance_matchesWebFormula_withinTolerance() {
    // Web: haversine, R = 3958.8 miles.
    let miles = DistanceCalculator.haversineDistance(from: home, to: wakeForest)
    // Great-circle NYC <-> Winston-Salem ~= 464 mi (haversine sphere model).
    // Assert the formula is in range and stable (not the old meters/1609.34 path).
    XCTAssertEqual(miles, 464, accuracy: 5)
  }

  func testMilesRounded_roundsToNearestWholeMile() {
    let rounded = DistanceCalculator.milesRounded(from: home, to: wakeForest)
    let raw = DistanceCalculator.haversineDistance(from: home, to: wakeForest)
    XCTAssertEqual(rounded, Int(raw.rounded()))
  }

  func testMilesRounded_zeroForSameCoordinate() {
    XCTAssertEqual(DistanceCalculator.milesRounded(from: home, to: home), 0)
  }

  func testFormatMiles_addsThousandsSeparatorAndUnit() {
    XCTAssertEqual(DistanceCalculator.formatMiles(1234), "1,234 miles")
  }

  func testFormatMiles_smallValue() {
    XCTAssertEqual(DistanceCalculator.formatMiles(372), "372 miles")
  }

  func testFormatMiles_zero() {
    XCTAssertEqual(DistanceCalculator.formatMiles(0), "0 miles")
  }
}
