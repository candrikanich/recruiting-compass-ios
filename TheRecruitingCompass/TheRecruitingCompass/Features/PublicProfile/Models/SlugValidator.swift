import Foundation

enum SlugValidation: Equatable {
    case empty, valid, invalidFormat, reserved
}

enum SlugValidator {
    private static let reserved: Set<String> = [
        "api", "p", "auth", "login", "signup", "join", "admin",
        "settings", "dashboard", "coaches", "schools", "help"
    ]
    private static let pattern = "^[a-z0-9][a-z0-9-]{0,28}[a-z0-9]$"

    static func validate(_ raw: String) -> SlugValidation {
        if raw.isEmpty { return .empty }
        if reserved.contains(raw) { return .reserved }
        let matches = raw.range(of: pattern, options: .regularExpression) != nil
        return matches ? .valid : .invalidFormat
    }
}
