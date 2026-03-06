import XCTest
@testable import TheRecruitingCompass

final class AppErrorTests: XCTestCase {

    // MARK: - init(statusCode:)

    func testStatusCode401MapsToUnauthorized() {
        XCTAssertEqual(AppError(statusCode: 401), .unauthorized)
    }

    func testStatusCode403MapsToForbidden() {
        XCTAssertEqual(AppError(statusCode: 403), .forbidden)
    }

    func testStatusCode404MapsToNotFound() {
        XCTAssertEqual(AppError(statusCode: 404), .notFound)
    }

    func testStatusCode500MapsToServerError() {
        if case .serverError(let code) = AppError(statusCode: 500) {
            XCTAssertEqual(code, 500)
        } else {
            XCTFail("Expected .serverError(500)")
        }
    }

    func testStatusCode502MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 502), .serviceUnavailable)
    }

    func testStatusCode503MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 503), .serviceUnavailable)
    }

    func testStatusCode504MapsToServiceUnavailable() {
        XCTAssertEqual(AppError(statusCode: 504), .serviceUnavailable)
    }

    func testUnknownStatusCodeMapsToUnknown() {
        XCTAssertEqual(AppError(statusCode: 418), .unknown)
    }

    // MARK: - init(from: Error)

    func testNotConnectedToInternetMapsToNetworkOffline() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(AppError(from: error), .networkOffline)
    }

    func testNetworkConnectionLostMapsToNetworkOffline() {
        let error = URLError(.networkConnectionLost)
        XCTAssertEqual(AppError(from: error), .networkOffline)
    }

    func testTimedOutMapsToServiceUnavailable() {
        let error = URLError(.timedOut)
        XCTAssertEqual(AppError(from: error), .serviceUnavailable)
    }

    func testUnknownURLErrorMapsToUnknown() {
        let error = URLError(.badURL)
        XCTAssertEqual(AppError(from: error), .unknown)
    }

    func testNonURLErrorMapsToUnknown() {
        let error = NSError(domain: "test", code: 999)
        XCTAssertEqual(AppError(from: error), .unknown)
    }

    // MARK: - Config

    func test404ConfigHeadline() {
        XCTAssertEqual(AppError.notFound.config.headline, "That page ran a different route.")
    }

    func test401ConfigHeadline() {
        XCTAssertEqual(AppError.unauthorized.config.headline, "You'll need to sign in first.")
    }

    func test403ConfigHeadline() {
        XCTAssertEqual(AppError.forbidden.config.headline, "This isn't your playbook.")
    }

    func test500ConfigHeadline() {
        XCTAssertEqual(AppError.serverError(statusCode: 500).config.headline, "We fumbled. It's on us.")
    }

    func testServiceUnavailableConfigHeadline() {
        XCTAssertEqual(AppError.serviceUnavailable.config.headline, "We're taking a timeout.")
    }

    func testNetworkOfflineConfigHeadline() {
        XCTAssertEqual(AppError.networkOffline.config.headline, "Looks like the connection dropped.")
    }

    func testUnknownConfigHeadline() {
        XCTAssertEqual(AppError.unknown.config.headline, "Something went sideways.")
    }

    func test403HasNoSecondaryButton() {
        XCTAssertNil(AppError.forbidden.config.secondaryButtonLabel)
    }

    func test404HasSecondaryButton() {
        XCTAssertNotNil(AppError.notFound.config.secondaryButtonLabel)
    }

    func test500ConfigStatusCode() {
        XCTAssertEqual(AppError.serverError(statusCode: 503).config.statusCode, 503)
    }

    func testNotFoundHasNoStatusCode() {
        XCTAssertNil(AppError.notFound.config.statusCode)
    }

    // MARK: - Identifiable

    func testServerErrorIdIncludesStatusCode() {
        XCTAssertEqual(AppError.serverError(statusCode: 500).id, "serverError-500")
    }

    func testNotFoundId() {
        XCTAssertEqual(AppError.notFound.id, "notFound")
    }
}
