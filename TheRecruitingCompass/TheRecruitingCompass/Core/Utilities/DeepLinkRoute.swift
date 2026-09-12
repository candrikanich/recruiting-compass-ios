import Foundation

enum DeepLinkRoute: Equatable {
  case resetPassword(token: String)
  case joinInvite(token: String)
  case guardianClaim(token: String)
  case unknown
}
