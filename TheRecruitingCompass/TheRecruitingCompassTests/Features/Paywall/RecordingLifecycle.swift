import Foundation
@testable import TheRecruitingCompass

/// Stands in for the RevenueCat SDK's lifecycle and records what the app asks of it, in order. `start` is the call
/// that, on the real SDK, first contacts RevenueCat.
final class RecordingLifecycle: @unchecked Sendable {
  enum Event: Equatable {
    case start(apiKey: String, appUserId: String)
    case logIn(String)
    case logOut
  }

  private let lock = NSLock()
  private var started = false
  private var recorded: [Event] = []

  var events: [Event] { lock.withLock { recorded } }
  var startCount: Int { events.filter { if case .start = $0 { true } else { false } }.count }
  var isStarted: Bool { lock.withLock { started } }

  var lifecycle: PurchasesLifecycle {
    PurchasesLifecycle(
      isStarted: { [self] in isStarted },
      start: { [self] apiKey, appUserId in
        lock.withLock {
          started = true
          recorded.append(.start(apiKey: apiKey, appUserId: appUserId))
        }
      },
      logIn: { [self] appUserId in lock.withLock { recorded.append(.logIn(appUserId)) } },
      logOut: { [self] in lock.withLock { recorded.append(.logOut) } }
    )
  }
}
