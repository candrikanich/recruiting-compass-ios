import Foundation

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
