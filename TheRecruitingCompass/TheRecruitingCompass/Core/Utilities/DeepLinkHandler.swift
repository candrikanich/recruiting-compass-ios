import Foundation

enum DeepLinkRoute: Equatable {
  case resetPassword(token: String)
  case joinInvite(token: String)
  case unknown
}

enum DeepLinkHandler {
  static let scheme = "recruiting-compass"
  static let universalLinkHosts: Set<String> = {
    var hosts: Set<String> = [
      "therecruitingcompass.com",
      "www.therecruitingcompass.com",
      "myrecruitingcompass.com",
      "www.myrecruitingcompass.com"
    ]
    #if DEBUG
    hosts.insert("localhost")
    hosts.insert("127.0.0.1")
    #endif
    return hosts
  }()

  private static let inviteTokenAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))

  private static func isValidInviteToken(_ token: String) -> Bool {
    !token.isEmpty && token.unicodeScalars.allSatisfy { inviteTokenAllowed.contains($0) }
  }

  static func parse(_ url: URL) -> DeepLinkRoute {
    // Custom scheme: recruiting-compass://reset-password?token=...
    if url.scheme == scheme {
      guard url.host == "reset-password",
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
            isValidInviteToken(token) else {
        return .unknown
      }
      return .resetPassword(token: token)
    }

    // Universal links: https://myrecruitingcompass.com/join?token=... or /invite/TOKEN
    guard url.scheme == "http" || url.scheme == "https",
          let host = url.host,
          universalLinkHosts.contains(host) else {
      return .unknown
    }

    // /join?token=...
    if url.path == "/join",
       let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
       isValidInviteToken(token) {
      return .joinInvite(token: token)
    }

    // /invite/:token (path component)
    if url.path.hasPrefix("/invite/") {
      let token = url.path
        .replacingOccurrences(of: "/invite/", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if isValidInviteToken(token) {
        return .joinInvite(token: token)
      }
    }

    return .unknown
  }
}
