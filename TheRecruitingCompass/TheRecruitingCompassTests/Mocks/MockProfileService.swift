import Foundation
@testable import TheRecruitingCompass

final class MockProfileService: ProfileManaging, @unchecked Sendable {
  var shouldThrowOnUpdatePersonalInfo = false
  var shouldThrowOnChangeEmail = false
  var shouldThrowOnChangePassword = false
  var shouldThrowOnGetDeletionStatus = false
  var shouldThrowOnRequestDeletion = false
  var shouldThrowOnCancelDeletion = false

  var errorToThrow: Error = ProfileServiceError.serverError("Mock error")

  var stubbedDeletionRequestedAt: Date?

  var updatePersonalInfoCallCount = 0
  var lastFullName: String?
  var lastPhone: String?
  var lastDateOfBirth: String?

  var changeEmailCallCount = 0
  var lastNewEmail: String?
  var lastEmailCurrentPassword: String?

  var changePasswordCallCount = 0
  var lastCurrentPassword: String?
  var lastNewPassword: String?

  var getDeletionStatusCallCount = 0
  var requestDeletionCallCount = 0
  var cancelDeletionCallCount = 0

  func updatePersonalInfo(fullName: String, phone: String?, dateOfBirth: String?) async throws {
    updatePersonalInfoCallCount += 1
    lastFullName = fullName
    lastPhone = phone
    lastDateOfBirth = dateOfBirth
    if shouldThrowOnUpdatePersonalInfo { throw errorToThrow }
  }

  func changeEmail(newEmail: String, currentPassword: String) async throws {
    changeEmailCallCount += 1
    lastNewEmail = newEmail
    lastEmailCurrentPassword = currentPassword
    if shouldThrowOnChangeEmail { throw errorToThrow }
  }

  func changePassword(currentPassword: String, newPassword: String) async throws {
    changePasswordCallCount += 1
    lastCurrentPassword = currentPassword
    lastNewPassword = newPassword
    if shouldThrowOnChangePassword { throw errorToThrow }
  }

  func getDeletionStatus() async throws -> Date? {
    getDeletionStatusCallCount += 1
    if shouldThrowOnGetDeletionStatus { throw errorToThrow }
    return stubbedDeletionRequestedAt
  }

  func requestDeletion() async throws {
    requestDeletionCallCount += 1
    if shouldThrowOnRequestDeletion { throw errorToThrow }
  }

  func cancelDeletion() async throws {
    cancelDeletionCallCount += 1
    if shouldThrowOnCancelDeletion { throw errorToThrow }
  }
}
