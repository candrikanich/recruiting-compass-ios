import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "VideoLinksService")

private struct VideoLinkInsertPayload: Encodable {
  let userId: String
  let familyUnitId: String?
  let platform: String
  let url: String
  let title: String?
  let position: Int

  enum CodingKeys: String, CodingKey {
    case userId = "user_id"
    case familyUnitId = "family_unit_id"
    case platform, url, title, position
  }
}

private struct VideoLinkUpdatePayload: Encodable {
  let platform: String?
  let url: String?
  let title: String?
  let position: Int?
}

final class VideoLinksServiceImpl: VideoLinksManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func fetchVideoLinks(userId: String) async throws -> [VideoLink] {
    logger.debug("Fetching video links for user: \(userId)")

    let links: [VideoLink] = try await supabaseManager.client
      .from("video_links")
      .select()
      .eq("user_id", value: userId)
      .order("position", ascending: true)
      .execute()
      .value

    logger.info("Fetched \(links.count) video links")
    return links
  }

  func createVideoLink(_ request: VideoLinkCreateRequest) async throws -> VideoLink {
    logger.debug("Creating video link for user: \(request.userId)")

    let payload = VideoLinkInsertPayload(
      userId: request.userId,
      familyUnitId: request.familyUnitId,
      platform: request.platform.rawValue,
      url: request.url,
      title: request.title,
      position: request.position
    )

    let link: VideoLink = try await supabaseManager.client
      .from("video_links")
      .insert(payload)
      .select()
      .single()
      .execute()
      .value

    logger.info("Created video link: \(link.id)")
    return link
  }

  func updateVideoLink(id: String, userId: String, _ request: VideoLinkUpdateRequest) async throws -> VideoLink {
    logger.debug("Updating video link: \(id)")

    let payload = VideoLinkUpdatePayload(
      platform: request.platform?.rawValue,
      url: request.url,
      title: request.title,
      position: request.position
    )

    let link: VideoLink = try await supabaseManager.client
      .from("video_links")
      .update(payload)
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .select()
      .single()
      .execute()
      .value

    logger.info("Updated video link: \(id)")
    return link
  }

  func deleteVideoLink(id: String, userId: String) async throws {
    logger.debug("Deleting video link: \(id)")

    try await supabaseManager.client
      .from("video_links")
      .delete()
      .eq("id", value: id)
      .eq("user_id", value: userId)
      .execute()

    logger.info("Deleted video link: \(id)")
  }
}
