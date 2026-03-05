//
//  HelpFeedbackService.swift
//  TheRecruitingCompass
//
//  Submits help center thumbs up/down feedback to Supabase (help_feedback table).
//

import Foundation
import OSLog
import Supabase

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "HelpFeedbackService")

protocol HelpFeedbackManaging: Sendable {
  func submitFeedback(page: String, helpful: Bool, userId: String) async throws
}

final class HelpFeedbackServiceImpl: HelpFeedbackManaging, Sendable {
  private let supabaseManager: SupabaseManager

  init(supabaseManager: SupabaseManager = .shared) {
    self.supabaseManager = supabaseManager
  }

  func submitFeedback(page: String, helpful: Bool, userId: String) async throws {
    logger.debug("Submitting help feedback: page=\(page) helpful=\(helpful)")
    let payload = HelpFeedbackInsert(page: page, helpful: helpful, userId: userId)
    do {
      try await supabaseManager.client
        .from("help_feedback")
        .insert(payload)
        .execute()
      logger.info("Help feedback submitted: page=\(page) helpful=\(helpful)")
    } catch {
      logger.error("submitFeedback failed: \(error.localizedDescription)")
      throw error
    }
  }
}

private struct HelpFeedbackInsert: Encodable {
  let page: String
  let helpful: Bool
  let userId: String

  enum CodingKeys: String, CodingKey {
    case page
    case helpful
    case userId = "user_id"
  }
}
