import Foundation

@Observable
@MainActor
final class VideoLinksEditorViewModel {
  nonisolated deinit {}

  var links: [VideoLink] = []
  var isLoading = false
  var isSubmitting = false
  var errorMessage: String?

  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }

  let isReadOnly: Bool
  let maxLinks = 5
  var canAddLink: Bool { !isReadOnly && links.count < maxLinks }

  private let service: any VideoLinksManaging
  private let athleteUserId: String
  private let familyUnitId: String?

  init(service: any VideoLinksManaging, athleteUserId: String,
       familyUnitId: String?, isReadOnly: Bool) {
    self.service = service
    self.athleteUserId = athleteUserId
    self.familyUnitId = familyUnitId
    self.isReadOnly = isReadOnly
  }

  func load() async {
    isLoading = true; defer { isLoading = false }
    do { links = try await service.fetchVideoLinks(userId: athleteUserId) }
    catch { errorMessage = String(localized: "Couldn't load video links. Please try again.") }
  }

  func addLink(platform: VideoLinkPlatform, url: String, title: String?) async -> Bool {
    guard canAddLink else {
      errorMessage = isReadOnly
        ? String(localized: "Only the player can edit video links.")
        : String(localized: "You can add up to 5 video links.")
      return false
    }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      let created = try await service.createVideoLink(.init(
        userId: athleteUserId, familyUnitId: familyUnitId,
        platform: platform, url: url,
        title: title?.isEmpty == true ? nil : title, position: links.count))
      links.append(created)
      return true
    } catch {
      errorMessage = String(localized: "Couldn't save the video link. Please try again.")
      return false
    }
  }

  func updateLink(id: String, platform: VideoLinkPlatform, url: String, title: String?) async -> Bool {
    guard !isReadOnly else {
      errorMessage = String(localized: "Only the player can edit video links.")
      return false
    }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      let updated = try await service.updateVideoLink(id: id, userId: athleteUserId, .init(
        platform: platform, url: url, title: title?.isEmpty == true ? nil : title, position: nil))
      if let i = links.firstIndex(where: { $0.id == id }) { links[i] = updated }
      return true
    } catch {
      errorMessage = String(localized: "Couldn't update the video link. Please try again.")
      return false
    }
  }

  func deleteLink(id: String) async -> Bool {
    guard !isReadOnly else { return false }
    isSubmitting = true; defer { isSubmitting = false }
    do {
      try await service.deleteVideoLink(id: id, userId: athleteUserId)
      links.removeAll { $0.id == id }
      return true
    } catch {
      errorMessage = String(localized: "Couldn't delete the video link. Please try again.")
      return false
    }
  }
}
