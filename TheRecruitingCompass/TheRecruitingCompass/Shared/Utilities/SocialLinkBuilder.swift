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

    /// One brand-social row entry: platform label, display handle (`@name`),
    /// destination URL, SF Symbol standing in for the brand mark (SF Symbols
    /// ships no official brand glyphs — parity with web's `SocialIcon.vue`
    /// icon set is at the platform/link level, not pixel iconography).
    struct BrandLink: Equatable {
        let platform: String
        let handle: String
        let url: URL
        let systemImage: String
    }

    /// X / Instagram / TikTok only — parity with web `buildSocialLinks`
    /// (public hero + footer brand-icon row). Facebook has no public brand row.
    static func brandLinks(from social: PublicProfileData.SocialSection) -> [BrandLink] {
        var links: [BrandLink] = []
        if let url = twitterURL(social.twitterHandle) {
            links.append(BrandLink(platform: "X", handle: "@\(clean(social.twitterHandle!))", url: url, systemImage: "at"))
        }
        if let url = instagramURL(social.instagramHandle) {
            links.append(BrandLink(
                platform: "Instagram", handle: "@\(clean(social.instagramHandle!))", url: url, systemImage: "camera"
            ))
        }
        if let url = tiktokURL(social.tiktokHandle) {
            links.append(BrandLink(
                platform: "TikTok", handle: "@\(clean(social.tiktokHandle!))", url: url, systemImage: "music.note"
            ))
        }
        return links
    }
}
