import SwiftUI

enum AppTab: Int {
  case dashboard = 0
  case schools = 1
  case coaches = 2
  case interactions = 3
  case more = 4
}

private struct SwitchTabKey: EnvironmentKey {
  static let defaultValue: (AppTab) -> Void = { _ in }
}

extension EnvironmentValues {
  var switchTab: (AppTab) -> Void {
    get { self[SwitchTabKey.self] }
    set { self[SwitchTabKey.self] = newValue }
  }
}

/// Switches to the More tab and drills into a specific section (e.g. Timeline),
/// which otherwise isn't reachable from other tabs.
private struct OpenMoreSectionKey: EnvironmentKey {
  static let defaultValue: (MoreMenuSection) -> Void = { _ in }
}

extension EnvironmentValues {
  var openMoreSection: (MoreMenuSection) -> Void {
    get { self[OpenMoreSectionKey.self] }
    set { self[OpenMoreSectionKey.self] = newValue }
  }
}
