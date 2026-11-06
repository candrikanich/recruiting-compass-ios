import Foundation

/// A way to reach a coach from a card or the detail rail.
enum CoachChannel: Equatable, Sendable {
  case email, text, call, twitter, instagram

  /// Email, text and Instagram DMs are outreach: their only safe path is Quick Communication, which runs the
  /// guardian lock and send guardrails. Call and viewing a Twitter profile are not.
  var isOutreach: Bool {
    switch self {
    case .email, .text, .instagram: return true
    case .call, .twitter: return false
    }
  }

  /// Channels the coach has contact info for, in display order. With `outreachEnabled` false (the
  /// `athlete_messages` kill switch) outreach channels are hidden outright rather than degraded to
  /// mailto:/sms:, which would bypass the guardian lock.
  static func visible(for coach: Coach, outreachEnabled: Bool) -> [CoachChannel] {
    var channels: [CoachChannel] = []
    if coach.contactEmail != nil { channels.append(.email) }
    if coach.contactPhone != nil { channels += [.text, .call] }
    if coach.contactTwitter != nil { channels.append(.twitter) }
    if coach.contactInstagram != nil { channels.append(.instagram) }
    return outreachEnabled ? channels : channels.filter { !$0.isOutreach }
  }
}
