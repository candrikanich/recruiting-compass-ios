import Foundation

enum PhotoError: LocalizedError {
    case compressionFailed
    case fileTooLarge

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Failed to compress photo"
        case .fileTooLarge: return "Photo must be less than 5MB"
        }
    }
}
