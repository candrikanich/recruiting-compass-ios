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

  func loadCompletionStatus() async {
    logger.debug("Loading completion status for settings badges")

    homeLocationStatus = await fetchForStatus(category: .location) { (loc: HomeLocation) in
      loc.latitude != nil && loc.longitude != nil
    }
    playerDetailsStatus = await fetchForStatus(category: .player) { (details: PlayerDetails) in
      details.graduationYear != nil || details.positions?.isEmpty == false
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
