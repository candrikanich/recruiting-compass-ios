import Foundation
@testable import TheRecruitingCompass

final class RecordingTransport: AnalyticsTransport, @unchecked Sendable {
  struct Event { let name: String; let properties: [String: Any] }
  private(set) var events: [Event] = []
  private(set) var identifies: [(userId: String, properties: [String: Any])] = []
  private(set) var resetCount = 0
  private(set) var unsets: [[String]] = []
  private(set) var order: [String] = []
  private(set) var clearPersistedCount = 0

  func identify(userId: String, properties: [String: Any]) { order.append("identify"); identifies.append((userId, properties)) }
  func reset() { resetCount += 1 }
  func recordOrder(_ label: String) { order.append(label) }
  func unsetPersonProperties(_ keys: [String]) { unsets.append(keys) }
  func clearPersistedPersonProperties() { order.append("clearPersisted"); clearPersistedCount += 1 }
  func capture(_ event: String, properties: [String: Any]) { order.append(event); events.append(Event(name: event, properties: properties)) }

  func events(named name: String) -> [Event] { events.filter { $0.name == name } }
}

/// Swaps in a recording transport and an isolated "started sent" store; call `restore()` in tearDown.
@MainActor
final class AnalyticsHarness {
  let transport = RecordingTransport()
  private let originalTransport = Analytics.transport
  private let originalDefaults = OnboardingAnalytics.defaults
  private let suite = "analytics-harness-\(UUID().uuidString)"

  init() {
    Analytics.transport = transport
    OnboardingAnalytics.defaults = UserDefaults(suiteName: suite) ?? .standard
  }

  func restore() {
    Analytics.transport = originalTransport
    OnboardingAnalytics.defaults.removePersistentDomain(forName: suite)
    OnboardingAnalytics.defaults = originalDefaults
  }
}
