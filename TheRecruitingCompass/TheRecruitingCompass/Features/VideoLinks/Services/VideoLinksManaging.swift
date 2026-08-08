import Foundation

struct VideoLinkCreateRequest: Sendable {
  let userId: String
  let familyUnitId: String?
  let platform: VideoLinkPlatform
  let url: String
  let title: String?
  let position: Int
}

struct VideoLinkUpdateRequest: Sendable {
  let platform: VideoLinkPlatform?
  let url: String?
  let title: String?
  let position: Int?
}

protocol VideoLinksManaging: Sendable {
  func fetchVideoLinks(userId: String) async throws -> [VideoLink]
  func createVideoLink(_ request: VideoLinkCreateRequest) async throws -> VideoLink
  func updateVideoLink(id: String, userId: String, _ request: VideoLinkUpdateRequest) async throws -> VideoLink
  func deleteVideoLink(id: String, userId: String) async throws
}
