import Foundation

enum DeepLinkRoute: Equatable {
  case resetPassword(token: String)
  case joinInvite(token: String)
  case unknown
}

enum DeepLinkHandler {
  static let scheme = "recruiting-compass"
  static let universalLinkHosts: Set<String> = [
    "recruiting-compass.com",
    "www.recruiting-compass.com",
    "localhost",
    "127.0.0.1",
  ]

  static func parse(_ url: URL) -> DeepLinkRoute {
    // Custom scheme: recruiting-compass://reset-password?token=...
    if url.scheme == scheme {
      guard url.host == "reset-password",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
            !token.isEmpty else {
        return .unknown
      }
      return .resetPassword(token: token)
    }

    // Universal links: https://recruiting-compass.com/join?token=... or /invite/TOKEN
    guard (url.scheme == "http" || url.scheme == "https"),
          let host = url.host,
          universalLinkHosts.contains(host) else {
      return .unknown
    }

    // /join?token=...
    if url.path == "/join",
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
       !token.isEmpty {
      return .joinInvite(token: token)
    }

    // /invite/:token (path component)
    if url.path.hasPrefix("/invite/") {
      let token = url.path
        .replacingOccurrences(of: "/invite/", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if !token.isEmpty {
        return .joinInvite(token: token)
      }
    }

    return .unknown
  }
}
