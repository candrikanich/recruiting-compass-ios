import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "AboutViewModel")

@Observable
@MainActor
final class AboutViewModel {
    var selectedSubject: FeedbackSubject = .general
    var message: String = ""
    var isLoading: Bool = false
    var submissionState: SubmissionState = .idle

    enum SubmissionState {
        case idle
        case success
        case failure(String)
    }

    private let feedbackService: FeedbackManaging

    init(feedbackService: FeedbackManaging? = nil) {
        self.feedbackService = feedbackService ?? FeedbackServiceImpl()
    }

  

    var isFormValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var characterCount: Int {
        message.count
    }

    func submit() async {
        guard isFormValid, !isLoading else { return }
        isLoading = true
        submissionState = .idle

        do {
            try await feedbackService.submit(subject: selectedSubject, message: message)
            submissionState = .success
            message = ""
            selectedSubject = .general
            try? await Task.sleep(for: .seconds(5))
            submissionState = .idle
        } catch {
            logger.error("Feedback submission failed: \(error.localizedDescription)")
            submissionState = .failure(error.localizedDescription)
        }

        isLoading = false
    }
}
