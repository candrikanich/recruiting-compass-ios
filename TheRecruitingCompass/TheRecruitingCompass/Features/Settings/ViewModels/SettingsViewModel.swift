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

  init(preferenceService: any PreferenceManaging) {
    self.preferenceService = preferenceService
  }

  // targetUserId: nil = current user; parent passes selectedAthlete.userId
  func loadCompletionStatus(targetUserId: String? = nil) async {
    logger.debug("Loading completion status for settings badges (targetUserId: \(targetUserId ?? "self"))")

    // Fetch location once: drives both the location badge and the player-completeness
    // home-location signal. Both use HomeLocation.isSet (zip OR coordinates) as the
    // canonical "complete" criterion. A fetch error leaves the badge nil (hidden).
    var hasHomeLocation = false
    do {
      let location: HomeLocation? = try await preferenceService.fetchPreferences(
        category: .location, userId: targetUserId)
      homeLocationStatus = location.map { $0.isSet ? .complete : .incomplete }
        ?? .incomplete
      hasHomeLocation = location?.isSet ?? false
    } catch {
      logger.error("Failed to fetch location badge status: \(error.localizedDescription)")
      homeLocationStatus = nil
    }

    playerDetailsStatus = await fetchForStatus(category: .player, userId: targetUserId) { (details: PlayerDetails) in
      details.isComplete(hasHomeLocation: hasHomeLocation)
    }
    schoolPreferencesStatus = await fetchForStatus(category: .school, userId: targetUserId) { (prefs: SchoolPreferences) in
      !prefs.preferences.isEmpty
    }

    let loc = String(describing: homeLocationStatus)
    let player = String(describing: playerDetailsStatus)
    let school = String(describing: schoolPreferencesStatus)
    logger.info("Badge status — location: \(loc), player: \(player), school: \(school)")
  }

  // MARK: - Private

  /// Returns nil if fetch throws (badge stays hidden), .incomplete if no data, .complete/.incomplete based on predicate
  private func fetchForStatus<T: Codable>(
    category: PreferenceCategory,
    userId: String?,
    isComplete: (T) -> Bool
  ) async -> SettingsBadgeStatus? {
    do {
      let value: T? = try await preferenceService.fetchPreferences(category: category, userId: userId)
      return value.map { isComplete($0) ? .complete : .incomplete } ?? .incomplete
    } catch {
      logger.error("Failed to fetch \(category.rawValue) badge status: \(error.localizedDescription)")
      return nil
    }
  }
}
