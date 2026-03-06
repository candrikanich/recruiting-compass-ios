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
  var homeLocationStatus: SettingsBadgeStatus?
  var playerDetailsStatus: SettingsBadgeStatus?
  var schoolPreferencesStatus: SettingsBadgeStatus?

  private let preferenceService: any PreferenceManaging

  init(preferenceService: any PreferenceManaging) {
    self.preferenceService = preferenceService
  }

  nonisolated deinit {}

  func loadCompletionStatus() async {
    logger.debug("Loading completion status for settings badges")

    async let locationStatus = fetchForStatus(category: .location) { (loc: HomeLocation) in
      loc.latitude != nil && loc.longitude != nil
    }
    async let playerStatus = fetchForStatus(category: .player) { (details: PlayerDetails) in
      details.graduationYear != nil || details.positions?.isEmpty == false
    }
    async let schoolStatus = fetchForStatus(category: .school) { (prefs: SchoolPreferences) in
      !prefs.preferences.isEmpty
    }

    homeLocationStatus = await locationStatus
    playerDetailsStatus = await playerStatus
    schoolPreferencesStatus = await schoolStatus

    logger.info(
      "Badge status — location: \(String(describing: self.homeLocationStatus)), player: \(String(describing: self.playerDetailsStatus)), school: \(String(describing: self.schoolPreferencesStatus))"
    )
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
