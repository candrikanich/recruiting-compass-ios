import Combine
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "CoachDetailViewModel")

@MainActor
final class CoachDetailViewModel: ObservableObject {
  @Published var coach: Coach?
  @Published var school: School?
  @Published var isLoading = false
  @Published var errorMessage: String?

  private let coachId: String
  private let coachesService: any CoachesManaging
  private let allCoaches: [Coach]
  private let allSchools: [School]

  nonisolated init(
    coachId: String,
    allCoaches: [Coach] = [],
    allSchools: [School] = [],
    coachesService: any CoachesManaging = CoachesServiceImpl(supabaseManager: .shared)
  ) {
    self.coachId = coachId
    self.allCoaches = allCoaches
    self.allSchools = allSchools
    self.coachesService = coachesService
  }

  func loadCoach() async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    // For now, use the passed-in coaches array since we don't have fetchCoach(id:) API yet
    if let foundCoach = allCoaches.first(where: { $0.id == coachId }) {
      coach = foundCoach
      if let foundSchool = allSchools.first(where: { $0.id == foundCoach.schoolId }) {
        school = foundSchool
      }
      logger.info("Loaded coach from cache: \(foundCoach.fullName)")
    } else {
      errorMessage = "Coach not found"
      logger.warning("Coach not found with ID: \(self.coachId)")
    }
  }
}
