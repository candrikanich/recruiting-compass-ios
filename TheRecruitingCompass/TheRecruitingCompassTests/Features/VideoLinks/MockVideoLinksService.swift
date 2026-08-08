import Foundation
@testable import TheRecruitingCompass

final class MockVideoLinksService: VideoLinksManaging, @unchecked Sendable {
  var links: [VideoLink] = []
  var createError: Error?
  var fetchError: Error?

  func fetchVideoLinks(userId: String) async throws -> [VideoLink] {
    if let fetchError { throw fetchError }
    return links.filter { $0.userId == userId }.sorted { $0.position < $1.position }
  }

  func createVideoLink(_ r: VideoLinkCreateRequest) async throws -> VideoLink {
    if let createError { throw createError }
    let link = VideoLink(
      id: UUID().uuidString, userId: r.userId, familyUnitId: r.familyUnitId,
      platform: r.platform, url: r.url, title: r.title, position: r.position,
      healthStatus: .unknown, lastHealthCheck: nil, createdAt: nil, updatedAt: nil
    )
    links.append(link)
    return link
  }

  func updateVideoLink(id: String, userId: String, _ r: VideoLinkUpdateRequest) async throws -> VideoLink {
    guard let i = links.firstIndex(where: { $0.id == id && $0.userId == userId }) else {
      throw NSError(domain: "MockVideoLinks", code: 404)
    }
    let e = links[i]
    let updated = VideoLink(
      id: e.id, userId: e.userId, familyUnitId: e.familyUnitId,
      platform: r.platform ?? e.platform, url: r.url ?? e.url,
      title: r.title ?? e.title, position: r.position ?? e.position,
      healthStatus: e.healthStatus, lastHealthCheck: e.lastHealthCheck,
      createdAt: e.createdAt, updatedAt: e.updatedAt
    )
    links[i] = updated
    return updated
  }

  func deleteVideoLink(id: String, userId: String) async throws {
    links.removeAll { $0.id == id && $0.userId == userId }
  }
}
