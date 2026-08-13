import XCTest
@testable import TheRecruitingCompass

final class SchoolEnrichmentDecodingTests: XCTestCase {
  func test_decodeSearchMatches() throws {
    let json = """
    {"success":true,"data":{"matches":[
      {"scorecardId":123,"name":"State U","state":"CA","city":"Davis",
       "studentSize":30000,"admissionRate":0.42}],"instruction":"x"}}
    """.data(using: .utf8)!
    let matches = try SchoolEnrichmentServiceImpl.decodeMatches(json)
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches[0].scorecardId, 123)
    XCTAssertEqual(matches[0].id, 123)
    XCTAssertEqual(matches[0].city, "Davis")
    XCTAssertEqual(matches[0].admissionRate, 0.42)
  }

  func test_decodeConfirmAcademicInfo() throws {
    let json = """
    {"success":true,"data":{"schoolId":"s1","message":"ok",
     "academicInfo":{"sat_25th":1120,"sat_75th":1330,"act_25th":24,"act_75th":30,
     "admission_rate":0.42,"student_size":30000}}}
    """.data(using: .utf8)!
    let info = try SchoolEnrichmentServiceImpl.decodeAcademicInfo(json)
    XCTAssertEqual(info.sat25th, 1120)
    XCTAssertEqual(info.act75th, 30)
    XCTAssertEqual(info.admissionRate, 0.42)
  }
}
