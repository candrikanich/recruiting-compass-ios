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
