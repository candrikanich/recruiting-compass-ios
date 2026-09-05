import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "DeadlinesListViewModel")

/// Unified Deadlines timeline: merges family-scoped `user_deadlines` rows
/// with the athlete's NCAA recruiting-calendar milestones
/// (`RecruitingCalendar.upcomingMilestones`) into one chronological list,
/// mirroring web's `useDeadlines`/`useRecruitingDeadlines` composables.
@Observable
@MainActor
final class DeadlinesListViewModel {

  nonisolated deinit {}

  // MARK: - State

  private(set) var deadlines: [Deadline] = []
  private(set) var milestones: [CalendarMilestone] = []
  private(set) var isLoading = false
  var errorMessage: String?
  var isShowingErrorAlert: Bool {
    get { errorMessage != nil }
    set { if !newValue { errorMessage = nil } }
  }
  var showAddSheet = false

  // MARK: - Dependencies

  private let service: any DeadlinesManaging
  private let familyManager: FamilyManager
  private let authManager: any AuthManaging
  private let preferenceService: any PreferenceManaging

  /// The user whose deadlines/profile we read. Mirrors Events/Dashboard:
  /// when a parent is viewing an athlete, deadlines surface for the athlete.
  var targetUserId: String? {
    familyManager.selectedAthlete?.userId ?? authManager.user?.id
  }

  var familyUnitId: String? {
    familyManager.familyUnitId
  }

  init(
    service: (any DeadlinesManaging)? = nil,
    familyManager: FamilyManager? = nil,
    authManager: (any AuthManaging)? = nil,
    preferenceService: (any PreferenceManaging)? = nil
  ) {
    self.service = service ?? DeadlinesServiceImpl()
    self.familyManager = familyManager ?? .shared
    self.authManager = authManager ?? AuthManager.shared
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
  }

  // MARK: - Derived (merged timeline)

  var unifiedDeadlines: [UnifiedDeadline] {
    DeadlinesMerge.unify(userDeadlines: deadlines, milestones: milestones)
  }

  private var todayISO: String {
    DeadlinesListViewModel.isoFormatter.string(from: .now)
  }

  var upcomingDeadlines: [UnifiedDeadline] {
    DeadlinesMerge.splitUpcomingPast(unifiedDeadlines, today: todayISO).upcoming
  }

  var pastDeadlines: [UnifiedDeadline] {
    DeadlinesMerge.splitUpcomingPast(unifiedDeadlines, today: todayISO).past
  }

  var groupedUpcoming: [(month: String, items: [UnifiedDeadline])] {
    DeadlinesMerge.groupByMonth(upcomingDeadlines)
  }

  var groupedPast: [(month: String, items: [UnifiedDeadline])] {
    // Past section reads most-recent-first, mirroring the spec's "collapsed,
    // sorted by date DESC" — reverse the ascending-grouped result.
    DeadlinesMerge.groupByMonth(pastDeadlines).reversed().map { $0 }
  }

  private static let isoFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

  // MARK: - Load

  func loadDeadlines() async {
    guard let familyUnitId else {
      logger.warning("No familyUnitId available for deadlines list")
      return
    }

    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      deadlines = try await service.fetchDeadlines(familyUnitId: familyUnitId)
    } catch {
      logger.error("Failed to load deadlines: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to load deadlines. Please try again.")
    }

    await loadMilestones()
  }

  /// Loads the target athlete's sport/gender/graduation year from player
  /// preferences and resolves the NCAA milestone side of the unified list.
  /// Errors are tolerated (leaves `milestones` empty) — the page still shows
  /// user deadlines even if the calendar lookup fails.
  private func loadMilestones() async {
    guard let userId = targetUserId else { return }
    do {
      let details: PlayerDetails? = try await preferenceService.fetchPreferences(category: .player, userId: userId)
      milestones = RecruitingCalendar.upcomingMilestones(
        todayISO,
        sport: details?.primarySport,
        division: "D1",
        gender: details?.gender,
        graduationYear: details?.graduationYear,
        limit: 20
      )
    } catch {
      logger.debug("Could not load player profile for milestones: \(error.localizedDescription)")
    }
  }

  func addDeadline(label: String, date: Date, category: DeadlineCategory) async -> Bool {
    let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    guard let userId = targetUserId, let familyUnitId else { return false }

    do {
      let request = DeadlineCreateRequest(
        userId: userId,
        familyUnitId: familyUnitId,
        label: trimmed,
        deadlineDate: DeadlinesListViewModel.isoFormatter.string(from: date),
        category: category,
        schoolId: nil
      )
      let created = try await service.createDeadline(request)
      deadlines.append(created)
      return true
    } catch {
      logger.error("Failed to create deadline: \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to save deadline. Please try again.")
      return false
    }
  }

  func removeDeadline(_ deadline: Deadline) async {
    guard let familyUnitId else { return }
    do {
      try await service.deleteDeadline(id: deadline.id, familyUnitId: familyUnitId)
      deadlines.removeAll { $0.id == deadline.id }
    } catch {
      logger.error("Failed to delete deadline \(deadline.id): \(error.localizedDescription)")
      errorMessage = String(localized: "Failed to delete deadline. Please try again.")
    }
  }
}
