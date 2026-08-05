//
//  HelpFeedbackViewModel.swift
//  TheRecruitingCompass
//
//  State + submission logic for the "Was this page helpful?" widget.
//

import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "HelpFeedbackViewModel")

@Observable
@MainActor
final class HelpFeedbackViewModel {
  nonisolated deinit {}

  var submitted = false
  var isLoading = false
  var errorMessage: String?

  let page: String
  private let feedbackService: HelpFeedbackManaging
  private let authManager: any AuthManaging

  init(
    page: String,
    feedbackService: HelpFeedbackManaging = HelpFeedbackServiceImpl(),
    authManager: (any AuthManaging)? = nil
  ) {
    self.page = page
    self.feedbackService = feedbackService
    self.authManager = authManager ?? AuthManager.shared
  }

  func submit(helpful: Bool) async {
    guard let userId = authManager.user?.id else { return }
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }

    do {
      try await feedbackService.submitFeedback(page: page, helpful: helpful, userId: userId)
      submitted = true
    } catch {
      logger.error("Help feedback submit failed: \(error.localizedDescription)")
      errorMessage = "Couldn't send feedback. Please try again."
    }
  }
}
