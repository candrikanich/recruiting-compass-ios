import Foundation
import Supabase

extension RealtimeClientV2 {
  /// A channel no other subscriber shares. `channel(_:)` returns any registered channel with the
  /// same topic, so when a screen is rebuilt (fold/unfold, rotation, tab switch) the new instance
  /// gets the old one's already-joined channel: it can't add listeners to it ("cannot call
  /// postgresChange after joining"), and the old instance's unsubscribe then closes it for both.
  /// Release it with `removeChannel(_:)` so the registry doesn't keep it.
  func exclusiveChannel(_ name: String) -> RealtimeChannelV2 {
    channel("\(name)-\(UUID().uuidString)")
  }
}
