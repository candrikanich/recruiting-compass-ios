import XCTest
@testable import TheRecruitingCompass

final class PlayerDetailsCodableTests: XCTestCase {
    func testCoreCoursesRoundTrips() throws {
        let json = #"{"core_courses":["AP Chemistry","Honors English"]}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PlayerDetails.self, from: json)
        XCTAssertEqual(decoded.coreCourses, ["AP Chemistry", "Honors English"])

        let reencoded = try JSONEncoder().encode(decoded)
        let obj = try JSONSerialization.jsonObject(with: reencoded) as! [String: Any]
        XCTAssertEqual(obj["core_courses"] as? [String], ["AP Chemistry", "Honors English"])
    }
}
