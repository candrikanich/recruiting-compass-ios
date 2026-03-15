import SwiftUI

enum AppTab: Int {
  case dashboard = 0
  case schools = 1
  case coaches = 2
  case interactions = 3
  case more = 4
}

extension EnvironmentValues {
  @Entry var switchTab: (AppTab) -> Void = { _ in }
}
