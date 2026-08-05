import Foundation

enum FeedbackSubject: String, CaseIterable {
    case bug
    case feature
    case question
    case general

    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .question: return "Question"
        case .general: return "General Feedback"
        }
    }
}
