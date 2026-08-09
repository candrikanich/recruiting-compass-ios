import UIKit
@testable import TheRecruitingCompass

final class MockProfilePhotoService: ProfilePhotoManaging, @unchecked Sendable {
  var shouldThrowOnUpload = false
  var shouldThrowOnDelete = false
  var errorToThrow: Error = NSError(domain: "MockProfilePhoto", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])

  var stubbedUploadURL = "https://example.com/photo.jpg"
  var stubbedCurrentURL: String?

  var uploadCallCount = 0
  var lastUploadUserId: String?
  var deleteCallCount = 0
  var lastDeleteUserId: String?
  var lastDeletePhotoURL: String?
  var currentPhotoURLCallCount = 0
  var lastCurrentPhotoURLUserId: String?

  func upload(image: UIImage, userId: String) async throws -> String {
    uploadCallCount += 1
    lastUploadUserId = userId
    if shouldThrowOnUpload { throw errorToThrow }
    return stubbedUploadURL
  }

  func delete(userId: String, currentPhotoURL: String) async throws {
    deleteCallCount += 1
    lastDeleteUserId = userId
    lastDeletePhotoURL = currentPhotoURL
    if shouldThrowOnDelete { throw errorToThrow }
  }

  func currentPhotoURL(userId: String) async throws -> String? {
    currentPhotoURLCallCount += 1
    lastCurrentPhotoURLUserId = userId
    return stubbedCurrentURL
  }
}
