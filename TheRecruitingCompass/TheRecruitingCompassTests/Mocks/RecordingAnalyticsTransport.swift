import Foundation
@testable import TheRecruitingCompass

/// Lock-guarded so analytics calls from any thread can't race the assertions.
final class RecordingTransport: AnalyticsTransport, @unchecked Sendable {
  struct Event { let name: String; let properties: [String: Any] }
  typealias Identify = (userId: String, properties: [String: Any])

  private let lock = NSLock()
  private var recordedEvents: [Event] = []
  private var recordedIdentifies: [Identify] = []
  private var recordedUnsets: [[String]] = []
  private var recordedOrder: [String] = []
  private var recordedResetCount = 0
  private var recordedClearCount = 0

  private func locked<T>(_ body: () -> T) -> T {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  var events: [Event] { locked { recordedEvents } }
  var identifies: [Identify] { locked { recordedIdentifies } }
  var unsets: [[String]] { locked { recordedUnsets } }
  var order: [String] { locked { recordedOrder } }
  var resetCount: Int { locked { recordedResetCount } }
  var clearPersistedCount: Int { locked { recordedClearCount } }

  func identify(userId: String, properties: [String: Any]) {
    locked {
      recordedOrder.append("identify")
      recordedIdentifies.append((userId, properties))
    }
  }

  func reset() {
    locked {
      recordedOrder.append("reset")
      recordedResetCount += 1
    }
  }

  func recordOrder(_ label: String) { locked { recordedOrder.append(label) } }
  func unsetPersonProperties(_ keys: [String]) { locked { recordedUnsets.append(keys) } }

  func clearPersistedPersonProperties() {
    locked {
      recordedOrder.append("clearPersisted")
      recordedClearCount += 1
    }
  }

  func capture(_ event: String, properties: [String: Any]) {
    locked {
      recordedOrder.append(event)
      recordedEvents.append(Event(name: event, properties: properties))
    }
  }

  func events(named name: String) -> [Event] { events.filter { $0.name == name } }
}

/// Swaps in a recording transport and an isolated "already sent" store; call `restore()` in tearDown.
@MainActor
final class AnalyticsHarness {
  let transport = RecordingTransport()
  private let originalTransport = Analytics.transport
  private let originalDefaults = Analytics.defaults
  private let suite = "analytics-harness-\(UUID().uuidString)"

  init() {
    Analytics.transport = transport
    Analytics.defaults = UserDefaults(suiteName: suite) ?? .standard
  }

  func restore() {
    Analytics.transport = originalTransport
    Analytics.defaults.removePersistentDomain(forName: suite)
    Analytics.defaults = originalDefaults
  }
}
