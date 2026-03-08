import Foundation
import Supabase
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "FeedbackService")

enum FeedbackSubject: String, CaseIterable {
    case bug = "bug"
    case feature = "feature"
    case question = "question"
    case general = "general"

    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .question: return "Question"
        case .general: return "General Feedback"
        }
    }
}

enum FeedbackError: LocalizedError {
    case notConfigured
    case serverError
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Feedback service is not available."
        case .serverError: return "Failed to send feedback. Please try again."
        case .networkError: return "Network error. Please check your connection."
        }
    }
}

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
        let token = try await supabaseManager.client.auth.session.accessToken

        struct Body: Encodable {
            let subject: String
            let message: String
        }

        let body = Body(subject: subject.rawValue, message: message)

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
