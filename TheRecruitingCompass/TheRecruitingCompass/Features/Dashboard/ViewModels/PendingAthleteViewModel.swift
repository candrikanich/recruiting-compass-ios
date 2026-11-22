import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "PendingAthlete")

/// The parent's first-run card while no athlete has joined: the school they added and read-only next steps for the
/// grade they staged. Everything here is derived from the family (never the signed-in parent's own profile) and
/// nothing on it can be completed. A failed read shows nothing rather than a guessed grade.
@Observable
@MainActor
final class PendingAthleteViewModel {

  nonisolated deinit {}

  private(set) var athleteFirstName: String?
  private(set) var steps: [WhatMattersItem] = []
  private(set) var favoriteSchoolName: String?
  private(set) var isLoaded = false

  @ObservationIgnored private var loadSequence = 0
  @ObservationIgnored private var loadedFamilyUnitId: String?

  private let service: any PendingAthleteManaging
  private let dashboardService: any DashboardManaging

  init(service: (any PendingAthleteManaging)? = nil, dashboardService: (any DashboardManaging)? = nil) {
    self.service = service ?? PendingAthleteServiceImpl(supabaseManager: .shared)
    self.dashboardService = dashboardService ?? DashboardServiceImpl(supabaseManager: .shared)
  }

  var isVisible: Bool { isLoaded && (!steps.isEmpty || favoriteSchoolName != nil) }
  var heading: String { FirstRunCopy.pendingStepsHeading(athleteFirstName: athleteFirstName) }
  var note: String { FirstRunCopy.pendingStepsNote(athleteFirstName: athleteFirstName) }

  /// Only the newest request writes, and a switch to another family drops the previous family's card at once.
  func load(familyUnitId: String?, referenceDate: Date = .now) async {
    loadSequence += 1
    let sequence = loadSequence
    if loadedFamilyUnitId != familyUnitId { clear() }
    loadedFamilyUnitId = familyUnitId
    guard let familyUnitId else { return }

    async let favorite = fetchFavoriteSchoolName(familyUnitId: familyUnitId)
    let (pending, steps) = await fetchSteps(familyUnitId: familyUnitId, referenceDate: referenceDate)
    let favoriteSchoolName = await favorite

    guard sequence == loadSequence else { return }
    athleteFirstName = pending?.athleteFirstName
    self.steps = steps
    self.favoriteSchoolName = favoriteSchoolName
    isLoaded = true
  }

  private func clear() {
    athleteFirstName = nil
    steps = []
    favoriteSchoolName = nil
    isLoaded = false
  }

  private func fetchSteps(
    familyUnitId: String, referenceDate: Date
  ) async -> (PendingAthlete?, [WhatMattersItem]) {
    do {
      guard let pending = try await service.fetchPendingAthlete(familyUnitId: familyUnitId) else { return (nil, []) }
      guard let grade = PendingAthleteSteps.grade(graduationYear: pending.graduationYear, referenceDate: referenceDate)
      else { return (pending, []) }
      let catalog = try await service.fetchTaskCatalog(gradeLevel: grade)
      return (pending, PendingAthleteSteps.steps(from: catalog, grade: grade))
    } catch {
      logger.error("pending athlete steps failed (non-fatal): \(error.localizedDescription, privacy: .public)")
      return (nil, [])
    }
  }

  private func fetchFavoriteSchoolName(familyUnitId: String) async -> String? {
    do {
      return try await dashboardService.fetchFirstRunSignals(familyUnitId: familyUnitId).favoriteSchoolName
    } catch {
      logger.error("pending athlete school failed (non-fatal): \(error.localizedDescription, privacy: .public)")
      return nil
    }
  }
}
