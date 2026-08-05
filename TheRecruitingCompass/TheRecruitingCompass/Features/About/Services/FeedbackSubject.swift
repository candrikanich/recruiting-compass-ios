import Foundation

enum FeedbackSubject: String, CaseIterable {
    case bug
    case feature
    case question
    case general

    var displayName: String {
        switch self {
        case .bug: return String(localized: "Bug Report")
        case .feature: return String(localized: "Feature Request")
        case .question: return String(localized: "Question")
        case .general: return String(localized: "General Feedback")
        }
    }
}
