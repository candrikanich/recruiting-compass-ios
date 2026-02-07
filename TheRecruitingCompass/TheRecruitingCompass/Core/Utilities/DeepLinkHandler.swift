import Foundation

enum DeepLinkRoute: Equatable {
  case resetPassword(token: String)
  case unknown
}

enum DeepLinkHandler {
  static let scheme = "recruiting-compass"

  static func parse(_ url: URL) -> DeepLinkRoute {
    guard url.scheme == scheme else {
      return .unknown
    }

    guard url.host == "reset-password" else {
      return .unknown
    }

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
          !token.isEmpty else {
      return .unknown
    }

    return .resetPassword(token: token)
  }
}
