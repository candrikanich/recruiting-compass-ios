import Foundation

/// Which contact channel(s) a coach exposes for sending a profile.
enum SendProfileChannelOption: Equatable {
    case email
    case text
    case both
    case none
}

/// The channel actually used for a send — drives interaction logging.
enum SendProfileChannel: Equatable {
    case email
    case text
}

/// Everything the composers and the send-logger need, resolved once when the
/// user taps "Send Profile".
struct SendProfileMessage: Equatable {
    let coachId: String
    let schoolId: String
    let familyUnitId: String
    let coachEmail: String?
    let coachPhone: String?
    let subject: String
    let emailBody: String
    let textBody: String
    let url: URL
}

/// The outcome of preparing a send: which UI the view should present next.
enum SendProfilePreparation: Equatable {
    case email(SendProfileMessage)
    case text(SendProfileMessage)
    case choice(SendProfileMessage)
    /// No usable email/phone on the coach — fall back to the system share sheet.
    case share(URL)
    case notPublished
    case failed
}

/// Pure copy + channel-selection logic. No async, no services — trivially testable.
enum SendProfileCopy {
    static func subject(playerName: String, graduationYear: Int?, positions: String) -> String {
        let namePrefix = graduationYear.map { "\($0) \(playerName)" } ?? playerName
        var subject = "\(namePrefix) Recruiting Profile"
        let trimmedPositions = positions.trimmingCharacters(in: .whitespaces)
        if !trimmedPositions.isEmpty {
            subject += " (\(trimmedPositions))"
        }
        return subject
    }

    static func emailBody(playerName: String, coachLastName: String, url: URL) -> String {
        let trimmedLastName = coachLastName.trimmingCharacters(in: .whitespaces)
        let greeting = trimmedLastName.isEmpty ? "Hi Coach," : "Hi Coach \(trimmedLastName),"
        return """
        \(greeting)

        I'd like to share \(playerName)'s recruiting profile with you:
        \(url.absoluteString)

        Thank you for your time.
        """
    }

    static func textBody(playerName: String, graduationYear: Int?, url: URL) -> String {
        let namePrefix = graduationYear.map { "\($0) \(playerName)" } ?? playerName
        return "\(namePrefix) — recruiting profile: \(url.absoluteString)"
    }

    static func channel(email: String?, phone: String?) -> SendProfileChannelOption {
        switch (email, phone) {
        case (.some, .some): return .both
        case (.some, .none): return .email
        case (.none, .some): return .text
        case (.none, .none): return .none
        }
    }
}
