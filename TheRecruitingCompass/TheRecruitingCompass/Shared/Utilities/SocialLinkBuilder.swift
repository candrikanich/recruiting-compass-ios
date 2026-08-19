import Foundation

/// Builds public social-profile URLs from stored handles, mirroring the web
/// app's `utils/socialMediaHandlers.ts` for cross-platform parity.
///
/// Handles are stored with or without a leading `@`; the `@` is stripped before
/// building the URL. Facebook is stored as a full URL rather than a handle.
enum SocialLinkBuilder {
    private static func clean(_ handle: String) -> String {
        handle.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "@", with: "")
    }

    static func twitterURL(_ handle: String?) -> URL? {
        guard let handle, !clean(handle).isEmpty else { return nil }
        return URL(string: "https://twitter.com/\(clean(handle))")
    }

    static func instagramURL(_ handle: String?) -> URL? {
        guard let handle, !clean(handle).isEmpty else { return nil }
        return URL(string: "https://instagram.com/\(clean(handle))")
    }

    static func tiktokURL(_ handle: String?) -> URL? {
        guard let handle, !clean(handle).isEmpty else { return nil }
        return URL(string: "https://tiktok.com/@\(clean(handle))")
    }

    static func facebookURL(_ urlString: String?) -> URL? {
        guard let urlString else { return nil }
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"
        return URL(string: normalized)
    }
}
