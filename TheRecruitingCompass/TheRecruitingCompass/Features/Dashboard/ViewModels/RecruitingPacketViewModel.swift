import Foundation
import UIKit
import OSLog
import Observation

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "RecruitingPacketViewModel")

/// Identity of the athlete a packet is generated for. Resolved by the dashboard (which knows whether
/// a parent is viewing an athlete) and passed in, so this view model stays free of FamilyManager.
struct RecruitingPacketAthlete: Equatable, Sendable {
  let userId: String
  let fullName: String?
  let email: String?
  let photoUrl: String?
}

/// A generated packet ready to share. `Identifiable` so it can drive a `.sheet(item:)`.
struct GeneratedPacket: Identifiable, Equatable {
  let id = UUID()
  let data: Data
  let filename: String
}

/// Drives the Recruiting Packet widget: lazily fetches the extra profile data (player details,
/// video links, interactions, photo) only when the athlete taps Generate, aggregates it, and
/// renders the PDF. Schools are passed in from the dashboard to avoid a redundant fetch.
@Observable
@MainActor
final class RecruitingPacketViewModel {

  nonisolated deinit {}

  var isGenerating = false
  var errorMessage: String?
  var generatedPacket: GeneratedPacket?

  private let preferenceService: any PreferenceManaging
  private let videoLinksService: any VideoLinksManaging
  private let dashboardService: any DashboardManaging

  init(
    preferenceService: (any PreferenceManaging)? = nil,
    videoLinksService: (any VideoLinksManaging)? = nil,
    dashboardService: (any DashboardManaging)? = nil
  ) {
    self.preferenceService = preferenceService ?? PreferenceServiceImpl(supabaseManager: .shared)
    self.videoLinksService = videoLinksService ?? VideoLinksServiceImpl(supabaseManager: .shared)
    self.dashboardService = dashboardService ?? DashboardServiceImpl(supabaseManager: .shared)
  }

  func generate(athlete: RecruitingPacketAthlete, schools: [School]) async {
    guard !isGenerating else { return }
    isGenerating = true
    errorMessage = nil
    defer { isGenerating = false }

    do {
      let details: PlayerDetails? = try await preferenceService.fetchPreferences(
        category: .player, userId: athlete.userId
      )
      let videoLinks = (try? await videoLinksService.fetchVideoLinks(userId: athlete.userId)) ?? []
      let interactions = (try? await dashboardService.fetchInteractions(userId: athlete.userId, limit: nil)) ?? []
      let photo = await loadPhoto(athlete.photoUrl)

      let data = buildPacketData(
        athlete: athlete,
        details: details,
        videoLinks: videoLinks,
        schools: schools,
        interactions: interactions
      )

      let pdfData = RecruitingPacketPDFGenerator().generate(data: data, photo: photo)
      generatedPacket = GeneratedPacket(data: pdfData, filename: filename(for: athlete))
    } catch {
      logger.error("Failed to generate recruiting packet: \(error.localizedDescription)")
      errorMessage = "Failed to generate recruiting packet"
    }
  }

  // MARK: - Aggregation

  private func buildPacketData(
    athlete: RecruitingPacketAthlete,
    details: PlayerDetails?,
    videoLinks: [VideoLink],
    schools: [School],
    interactions: [Interaction]
  ) -> RecruitingPacketData {
    let phone: String? = (details?.allowSharePhone == true) ? details?.phone : nil

    let position = CanonicalPositions.formatPositionsShort(
      sport: details?.primarySport,
      positions: details?.positions,
      fallback: details?.primaryPosition
    )

    let videoEntries: [RecruitingPacketData.VideoLinkEntry] = videoLinks.map { link in
      let label = (link.title?.isEmpty == false ? link.title! : link.platform.displayName)
      return RecruitingPacketData.VideoLinkEntry(label: label, url: link.url)
    }

    let athleteBlock = RecruitingPacketData.Athlete(
      fullName: athlete.fullName,
      email: athlete.email,
      phone: phone,
      height: HeightFormatter.feetInches(details?.heightInches),
      weight: details?.weightLbs.map { "\($0) lbs" },
      position: position.isEmpty ? nil : position,
      batsThrows: RecruitingPacketData.batsThrows(bats: details?.bats, throws: details?.throws_),
      schoolName: details?.schoolName?.isEmpty == false ? details?.schoolName : details?.highSchool,
      graduationYear: details?.graduationYear,
      gpa: details?.gpa,
      satScore: details?.satScore,
      actScore: details?.actScore,
      coreCourses: details?.coreCourses ?? [],
      videoLinks: videoEntries,
      socialMedia: RecruitingPacketData.socialEntries(
        instagram: details?.instagramHandle,
        twitter: details?.twitterHandle,
        tiktok: details?.tiktokHandle
      )
    )

    return RecruitingPacketData(
      athlete: athleteBlock,
      tiers: RecruitingPacketData.groupSchoolsByTier(schools),
      activity: RecruitingPacketData.activitySummary(schoolCount: schools.count, interactions: interactions)
    )
  }

  private func filename(for athlete: RecruitingPacketAthlete) -> String {
    let base = (athlete.fullName ?? "Athlete")
      .components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted)
      .joined()
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: " ", with: "_")
    let safe = base.isEmpty ? "Athlete" : base
    return "\(safe)_RecruitingPacket.pdf"
  }

  private func loadPhoto(_ urlString: String?) async -> UIImage? {
    guard let urlString, let url = URL(string: urlString) else { return nil }
    do {
      let (data, _) = try await URLSession.shared.data(from: url)
      return UIImage(data: data)
    } catch {
      logger.debug("Packet photo load failed: \(error.localizedDescription)")
      return nil
    }
  }
}
