import Auth
import XCTest
@testable import TheRecruitingCompass

/// #406: a wrong password reached Supabase but showed "An error occurred. Please try again." because the
/// raw SDK error ("Invalid login credentials") never became the app's `.invalidCredentials`.
final class SupabaseAuthErrorsTests: XCTestCase {

  private func apiError(_ message: String, code: Auth.ErrorCode, status: Int = 400) -> Auth.AuthError {
    .api(
      message: message,
      errorCode: code,
      underlyingData: Data(),
      underlyingResponse: HTTPURLResponse(
        url: URL(string: "https://example.supabase.co/auth/v1/token")!,
        statusCode: status, httpVersion: nil, headerFields: nil
      )!
    )
  }

  func test_signInError_wrongPassword_mapsToInvalidCredentials() {
    let error = apiError("Invalid login credentials", code: .invalidCredentials)

    let mapped = SupabaseAuthErrors.signInError(for: error)

    XCTAssertEqual(mapped?.errorDescription, TheRecruitingCompass.AuthError.invalidCredentials.errorDescription)
  }

  func test_signInError_unconfirmedEmail_mapsToEmailNotVerified() {
    let error = apiError("Email not confirmed", code: .emailNotConfirmed)

    let mapped = SupabaseAuthErrors.signInError(for: error)

    XCTAssertEqual(mapped?.errorDescription, TheRecruitingCompass.AuthError.emailNotVerified.errorDescription)
  }

  func test_signInError_rateLimited_mapsToTooManyAttempts() {
    let error = apiError("Request rate limit reached", code: .overRequestRateLimit, status: 429)

    let mapped = SupabaseAuthErrors.signInError(for: error)

    XCTAssertEqual(
      mapped?.errorDescription,
      TheRecruitingCompass.AuthError.tooManyAttempts(retryAfter: nil).errorDescription
    )
  }

  func test_signInError_captchaRejected_mapsToCaptchaFailed() {
    let error = apiError("captcha protection: request disallowed", code: .captchaFailed)

    let mapped = SupabaseAuthErrors.signInError(for: error)

    XCTAssertEqual(mapped?.errorDescription, TheRecruitingCompass.AuthError.captchaFailed.errorDescription)
  }

  func test_signInError_untypedInvalidLoginMessage_mapsToInvalidCredentials() {
    let error = NSError(domain: "wrapped", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid login credentials"])

    let mapped = SupabaseAuthErrors.signInError(for: error)

    XCTAssertEqual(mapped?.errorDescription, TheRecruitingCompass.AuthError.invalidCredentials.errorDescription)
  }

  func test_signInError_unrelatedError_isLeftForCallerToHandle() {
    let error = apiError("Database error querying schema", code: .unexpectedFailure, status: 500)

    XCTAssertNil(SupabaseAuthErrors.signInError(for: error))
  }
}
