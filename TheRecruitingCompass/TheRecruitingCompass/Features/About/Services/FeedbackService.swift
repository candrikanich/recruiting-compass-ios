import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FeedbackService")

protocol FeedbackManaging: Sendable {
    func submit(subject: FeedbackSubject, message: String) async throws
}

final class FeedbackServiceImpl: FeedbackManaging, Sendable {
    private let supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager = .shared) {
        self.supabaseManager = supabaseManager
    }

    func submit(subject: FeedbackSubject, message: String) async throws {
        guard let baseURL = SupabaseConfig.apiBaseURL else {
            logger.error("apiBaseURL not configured")
            throw FeedbackError.notConfigured
        }

        let url = baseURL.appendingPathComponent("api/feedback")
        let session = try await supabaseManager.client.auth.session
        let token = session.accessToken

        // Web `feedbackSchema` requires `email` and `feedbackType` (bug|feature|other);
        // `name` is optional but included so the notification email has a sender.
        let email = session.user.email ?? ""
        let name: String? = session.user.userMetadata["full_name"].flatMap { value in
            if case let string as String = value.value { return string }
            return nil
        }

        struct Body: Encodable {
            let name: String?
            let email: String
            let feedbackType: String
            let message: String
        }

        let body = Body(
            name: name,
            email: email,
            feedbackType: subject.feedbackType,
            message: message
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        logger.debug("Submitting feedback: subject=\(subject.rawValue)")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("Feedback network error: \(error.localizedDescription)")
            throw FeedbackError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "(unreadable)"
            logger.error("Feedback failed: body=\(body, privacy: .private)")
            throw FeedbackError.serverError
        }

        logger.info("Feedback submitted successfully: subject=\(subject.rawValue)")
    }
}
