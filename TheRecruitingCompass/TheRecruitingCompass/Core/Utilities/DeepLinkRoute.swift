import Foundation

enum DeepLinkRoute: Equatable {
  case resetPassword(token: String)
  case joinInvite(token: String)
  case unknown
}
