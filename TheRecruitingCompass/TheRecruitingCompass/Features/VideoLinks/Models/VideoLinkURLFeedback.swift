import Foundation

/// What the Add/Edit sheet shows for the URL typed so far. No message while the input could still become a
/// valid link (`h`, `https:/`), so it doesn't nag mid-typing.
struct VideoLinkURLFeedback: Equatable {
  let canSave: Bool
  let showsMessage: Bool

  init(input: String) {
    canSave = HTTPURL.isValid(input)
    showsMessage = !input.isEmpty && !canSave && !HTTPURL.canBecomeValid(input)
  }
}
