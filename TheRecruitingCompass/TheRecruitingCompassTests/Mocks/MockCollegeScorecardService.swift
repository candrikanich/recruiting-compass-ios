import Foundation
@testable import TheRecruitingCompass

final class MockCollegeScorecardService: CollegeScorecardManaging {
  var stubbedResult: CollegeDataResult?
  var shouldThrowError = false
  var errorToThrow: Error = CollegeDataError.schoolNotFound

  func lookupCollege(name: String) async throws -> CollegeDataResult? {
    if shouldThrowError {
      throw errorToThrow
    }
    return stubbedResult
  }
}
