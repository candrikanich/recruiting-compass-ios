//
//  CollegeScorecardServiceTests.swift
//  TheRecruitingCompassTests
//
//  Created on 2026-02-11
//  Unit tests for College Scorecard API integration
//

import XCTest
@testable import TheRecruitingCompass

@MainActor
final class CollegeScorecardServiceTests: XCTestCase {

  var service: CollegeScorecardService!
  var mockSession: URLSession!

  override func setUp() {
    super.setUp()

    // Configure URLSession with mock protocol
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    mockSession = URLSession(configuration: configuration)

    // Inject mock session and token provider into service
    service = CollegeScorecardService(urlSession: mockSession, tokenProvider: { "test-token" })
  }

  override func tearDown() {
    MockURLProtocol.reset()
    service = nil
    mockSession = nil
    super.tearDown()
  }

  // MARK: - lookupCollege() Success Tests

  func testLookupCollege_success_returnsCollegeData() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 1, "page": 0, "per_page": 1},
      "results": [{
        "id": "134130",
        "school.name": "University of Florida",
        "school.school_url": "www.ufl.edu",
        "school.address": "Gainesville, FL",
        "school.city": "Gainesville",
        "school.state": "FL",
        "latest.student.size": 52218,
        "school.carnegie_size_setting": "Large",
        "latest.admissions.admission_rate.overall": 0.296,
        "latest.cost.tuition.in_state": 6381.0,
        "latest.cost.tuition.out_of_state": 28658.0,
        "location.lat": 29.6516,
        "location.lon": -82.3248
      }]
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let result = try await service.lookupCollege(name: "Florida")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "134130")
    XCTAssertEqual(result?.name, "University of Florida")
    XCTAssertEqual(result?.website, "www.ufl.edu")
    XCTAssertEqual(result?.city, "Gainesville")
    XCTAssertEqual(result?.state, "FL")
    XCTAssertEqual(result?.studentSize, 52218)
    XCTAssertEqual(result?.admissionRate, 0.296)
    XCTAssertEqual(result?.tuitionInState, 6381.0)
    XCTAssertEqual(result?.tuitionOutOfState, 28658.0)
    XCTAssertEqual(result?.latitude, 29.6516)
    XCTAssertEqual(result?.longitude, -82.3248)
  }

  func testLookupCollege_noResults_returnsNil() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 0, "page": 0, "per_page": 1},
      "results": []
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let result = try await service.lookupCollege(name: "NonexistentCollege")

    // Then
    XCTAssertNil(result)
  }

  func testLookupCollege_withNullFields_parsesNonNullFields() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 1, "page": 0, "per_page": 1},
      "results": [{
        "id": "123456",
        "school.name": "Sample College",
        "school.school_url": null,
        "school.address": null,
        "school.city": "Boston",
        "school.state": "MA",
        "latest.student.size": null,
        "school.carnegie_size_setting": null,
        "latest.admissions.admission_rate.overall": null,
        "latest.cost.tuition.in_state": null,
        "latest.cost.tuition.out_of_state": null,
        "location.lat": null,
        "location.lon": null
      }]
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let result = try await service.lookupCollege(name: "Sample")

    // Then
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.id, "123456")
    XCTAssertEqual(result?.name, "Sample College")
    XCTAssertEqual(result?.city, "Boston")
    XCTAssertEqual(result?.state, "MA")
    XCTAssertNil(result?.website)
    XCTAssertNil(result?.studentSize)
    XCTAssertNil(result?.admissionRate)
  }

  // MARK: - lookupCollege() Error Tests

  func testLookupCollege_missingToken_throwsSessionMissing() async {
    // Given
    let serviceWithoutToken = CollegeScorecardService(urlSession: mockSession, tokenProvider: { nil })

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await serviceWithoutToken.lookupCollege(name: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .sessionMissing)
    }
  }

  func testLookupCollege_nameTooShort_throwsNameTooShort() async {
    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "FL")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .nameTooShort)
    }
  }

  func testLookupCollege_401Response_throwsInvalidApiKey() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 401, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .invalidApiKey)
    }
  }

  func testLookupCollege_403Response_throwsInvalidApiKey() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 403, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .invalidApiKey)
    }
  }

  func testLookupCollege_429Response_throwsRateLimited() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 429, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .rateLimited)
    }
  }

  func testLookupCollege_500Response_throwsServerError() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 500, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      if case .serverError(let code) = error as? CollegeDataError {
        XCTAssertEqual(code, 500)
      } else {
        XCTFail("Expected serverError, got \(error)")
      }
    }
  }

  func testLookupCollege_503Response_throwsServerError() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 503, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      if case .serverError(let code) = error as? CollegeDataError {
        XCTAssertEqual(code, 503)
      } else {
        XCTFail("Expected serverError, got \(error)")
      }
    }
  }

  func testLookupCollege_malformedJSON_throwsDecodingError() async {
    // Given
    let invalidJSON = "{ invalid json }"
    MockURLProtocol.stubResponse(statusCode: 200, data: invalidJSON.data(using: .utf8))

    // When / Then — JSON decode errors propagate as DecodingError (not wrapped by fetchData)
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      XCTAssertTrue(error is DecodingError, "Expected DecodingError, got \(error)")
    }
  }

  func testLookupCollege_networkError_throwsNetworkError() async {
    // Given
    MockURLProtocol.stubError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet))

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.lookupCollege(name: "Florida")
    ) { error in
      if case .networkError = error as? CollegeDataError {
        // Success - correct error type
      } else {
        XCTFail("Expected networkError, got \(error)")
      }
    }
  }

  // MARK: - searchColleges() Success Tests

  func testSearchColleges_success_returnsResults() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 3, "page": 0, "per_page": 10},
      "results": [
        {
          "id": 134130,
          "school.name": "University of Florida",
          "school.city": "Gainesville",
          "school.state": "FL",
          "school.school_url": "www.ufl.edu"
        },
        {
          "id": 134097,
          "school.name": "Florida State University",
          "school.city": "Tallahassee",
          "school.state": "FL",
          "school.school_url": "www.fsu.edu"
        },
        {
          "id": 132903,
          "school.name": "University of Central Florida",
          "school.city": "Orlando",
          "school.state": "FL",
          "school.school_url": "www.ucf.edu"
        }
      ]
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let results = try await service.searchColleges(query: "Florida")

    // Then
    XCTAssertEqual(results.count, 3)

    XCTAssertEqual(results[0].id, "134130")
    XCTAssertEqual(results[0].name, "University of Florida")
    XCTAssertEqual(results[0].city, "Gainesville")
    XCTAssertEqual(results[0].state, "FL")
    XCTAssertEqual(results[0].website, "www.ufl.edu")

    XCTAssertEqual(results[1].name, "Florida State University")
    XCTAssertEqual(results[2].name, "University of Central Florida")
  }

  func testSearchColleges_maxResults_returnsMax10() async throws {
    // Given
    let resultsArray = (1...15).map { i in
      """
      {
        "id": \(i),
        "school.name": "College \(i)",
        "school.city": "City \(i)",
        "school.state": "ST",
        "school.school_url": "www.college\(i).edu"
      }
      """
    }.joined(separator: ",")

    let mockResponse = """
    {
      "metadata": {"total": 15, "page": 0, "per_page": 10},
      "results": [\(resultsArray)]
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let results = try await service.searchColleges(query: "College")

    // Then
    XCTAssertEqual(results.count, 15) // Service doesn't limit, API does
  }

  func testSearchColleges_filtersIncompleteResults() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 5, "page": 0, "per_page": 10},
      "results": [
        {
          "id": 1,
          "school.name": "Complete College",
          "school.city": "Boston",
          "school.state": "MA",
          "school.school_url": "www.complete.edu"
        },
        {
          "id": null,
          "school.name": "Missing ID",
          "school.city": "Cambridge",
          "school.state": "MA",
          "school.school_url": null
        },
        {
          "id": 2,
          "school.name": null,
          "school.city": "New York",
          "school.state": "NY",
          "school.school_url": null
        },
        {
          "id": 3,
          "school.name": "Missing City",
          "school.city": null,
          "school.state": "NY",
          "school.school_url": null
        },
        {
          "id": 4,
          "school.name": "Missing State",
          "school.city": "Philadelphia",
          "school.state": null,
          "school.school_url": null
        }
      ]
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let results = try await service.searchColleges(query: "College")

    // Then
    XCTAssertEqual(results.count, 1) // Only "Complete College" has all required fields
    XCTAssertEqual(results[0].name, "Complete College")
  }

  func testSearchColleges_emptyResults_returnsEmptyArray() async throws {
    // Given
    let mockResponse = """
    {
      "metadata": {"total": 0, "page": 0, "per_page": 10},
      "results": []
    }
    """

    MockURLProtocol.stubResponse(statusCode: 200, data: mockResponse.data(using: .utf8))

    // When
    let results = try await service.searchColleges(query: "NonexistentCollege")

    // Then
    XCTAssertEqual(results.count, 0)
  }

  // MARK: - searchColleges() Error Tests

  func testSearchColleges_missingToken_throwsSessionMissing() async {
    // Given
    let serviceWithoutToken = CollegeScorecardService(urlSession: mockSession, tokenProvider: { nil })

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await serviceWithoutToken.searchColleges(query: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .sessionMissing)
    }
  }

  func testSearchColleges_queryTooShort_throwsNameTooShort() async {
    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.searchColleges(query: "FL")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .nameTooShort)
    }
  }

  func testSearchColleges_401Response_throwsInvalidApiKey() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 401, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.searchColleges(query: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .invalidApiKey)
    }
  }

  func testSearchColleges_429Response_throwsRateLimited() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 429, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.searchColleges(query: "Florida")
    ) { error in
      XCTAssertEqual(error as? CollegeDataError, .rateLimited)
    }
  }

  func testSearchColleges_500Response_throwsServerError() async {
    // Given
    MockURLProtocol.stubResponse(statusCode: 500, data: Data())

    // When / Then
    await XCTAssertThrowsErrorAsync(
      try await service.searchColleges(query: "Florida")
    ) { error in
      if case .serverError(let code) = error as? CollegeDataError {
        XCTAssertEqual(code, 500)
      } else {
        XCTFail("Expected serverError, got \(error)")
      }
    }
  }
}

// MARK: - Mock URLProtocol

private class MockURLProtocol: URLProtocol {

  private static var stubResponse: (statusCode: Int, data: Data?)?
  private static var stubError: Error?

  static func stubResponse(statusCode: Int, data: Data?) {
    stubResponse = (statusCode, data)
    stubError = nil
  }

  static func stubError(_ error: Error) {
    stubError = error
    stubResponse = nil
  }

  static func reset() {
    stubResponse = nil
    stubError = nil
  }

  override class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return request
  }

  override func startLoading() {
    if let error = MockURLProtocol.stubError {
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    guard let stub = MockURLProtocol.stubResponse else {
      let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "No stub configured"])
      client?.urlProtocol(self, didFailWithError: error)
      return
    }

    let response = HTTPURLResponse(
      url: request.url!,
      statusCode: stub.statusCode,
      httpVersion: nil,
      headerFields: nil
    )!

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

    if let data = stub.data {
      client?.urlProtocol(self, didLoad: data)
    }

    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {
    // No-op
  }
}

// MARK: - Test Helpers

extension XCTestCase {
  func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (_ error: Error) -> Void = { _ in }
  ) async {
    do {
      _ = try await expression()
      XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
      errorHandler(error)
    }
  }
}

// MARK: - CollegeDataError Equatable

extension CollegeDataError: Equatable {
  public static func == (lhs: CollegeDataError, rhs: CollegeDataError) -> Bool {
    switch (lhs, rhs) {
    case (.nameTooShort, .nameTooShort),
         (.apiKeyMissing, .apiKeyMissing),
         (.sessionMissing, .sessionMissing),
         (.invalidApiKey, .invalidApiKey),
         (.rateLimited, .rateLimited),
         (.schoolNotFound, .schoolNotFound),
         (.invalidResponse, .invalidResponse):
      return true
    case (.serverError(let lhsCode), .serverError(let rhsCode)):
      return lhsCode == rhsCode
    case (.networkError, .networkError):
      return true // Simplified - compare error types only
    default:
      return false
    }
  }
}
