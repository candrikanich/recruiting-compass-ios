import Foundation
import Observation
import OSLog

private let logger = Logger(
  subsystem: "com.chrisandrikanich.TheRecruitingCompass",
  category: "SettingsViewModel"
)

@Observable
@MainActor
final class SettingsViewModel {

  nonisolated deinit {}
  var homeLocationStatus: SettingsBadgeStatus?
  var playerDetailsStatus: SettingsBadgeStatus?
  var schoolPreferencesStatus: SettingsBadgeStatus?

  private let preferenceService: any PreferenceManaging
  private let videoLinksService: any VideoLinksManaging
  private let authManager: any AuthManaging

  init(
    preferenceService: any PreferenceManaging,
    videoLinksService: any VideoLinksManaging = VideoLinksServiceImpl(),
    authManager: (any AuthManaging)? = nil
  ) {
    self.preferenceService = preferenceService
    self.videoLinksService = videoLinksService
    self.authManager = authManager ?? AuthManager.shared
  }

  func loadCompletionStatus() async {
    logger.debug("Loading completion status for settings badges")

    // Fetch location once: drives both the location badge (needs coordinates) and
    // the player-completeness home-location signal (zip OR coordinates). A fetch
    // error leaves the badge nil (hidden), matching the other badges' semantics.
    var hasHomeLocation = false
    do {
      let location: HomeLocation? = try await preferenceService.fetchPreferences(category: .location)
      homeLocationStatus = location.map { ($0.latitude != nil && $0.longitude != nil) ? .complete : .incomplete }
        ?? .incomplete
      hasHomeLocation = location?.isSet ?? false
    } catch {
      logger.error("Failed to fetch location badge status: \(error.localizedDescription)")
      homeLocationStatus = nil
    }

    let hasHighlightVideo = await fetchHasHighlightVideo()
    playerDetailsStatus = await fetchForStatus(category: .player) { (details: PlayerDetails) in
      details.isComplete(hasHighlightVideo: hasHighlightVideo, hasHomeLocation: hasHomeLocation)
    }
    schoolPreferencesStatus = await fetchForStatus(category: .school) { (prefs: SchoolPreferences) in
      !prefs.preferences.isEmpty
    }

    let loc = String(describing: homeLocationStatus)
    let player = String(describing: playerDetailsStatus)
    let school = String(describing: schoolPreferencesStatus)
    logger.info("Badge status — location: \(loc), player: \(player), school: \(school)")
  }

  // MARK: - Private

  /// Whether the signed-in athlete has ≥1 highlight video. Non-fatal on failure.
  private func fetchHasHighlightVideo() async -> Bool {
    guard let userId = authManager.user?.id else { return false }
    do {
      return try await !videoLinksService.fetchVideoLinks(userId: userId).isEmpty
    } catch {
      logger.error("Failed to fetch video links for badge: \(error.localizedDescription)")
      return false
    }
  }

  /// Returns nil if fetch throws (badge stays hidden), .incomplete if no data, .complete/.incomplete based on predicate
  private func fetchForStatus<T: Codable>(
    category: PreferenceCategory,
    isComplete: (T) -> Bool
  ) async -> SettingsBadgeStatus? {
    do {
      let value: T? = try await preferenceService.fetchPreferences(category: category)
      return value.map { isComplete($0) ? .complete : .incomplete } ?? .incomplete
    } catch {
      logger.error("Failed to fetch \(category.rawValue) badge status: \(error.localizedDescription)")
      return nil
    }
  }
}
