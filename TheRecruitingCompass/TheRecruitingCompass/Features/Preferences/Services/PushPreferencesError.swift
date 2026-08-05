import Foundation

enum PushPreferencesError: LocalizedError {
    case fetchFailed(String)
    case updateFailed(String)
    case seedFailed(String)

    var errorDescription: String? {
        switch self {
        case .fetchFailed(let message):
            return "Failed to load push preferences: \(message)"
        case .updateFailed(let message):
            return "Failed to update push preference: \(message)"
        case .seedFailed(let message):
            return "Failed to seed push preferences: \(message)"
        }
    }
}
