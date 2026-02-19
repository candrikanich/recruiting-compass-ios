import Foundation
import Network
import Observation

/// Monitors network reachability. Use to show an offline banner or gate network-dependent UI.
@Observable
@MainActor
final class NetworkMonitor {
  var isConnected: Bool = true

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "com.recruitingcompass.networkmonitor")

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      guard let self else { return }
      let connected = path.status == .satisfied
      let ref = self
      Task { @MainActor in
        ref.isConnected = connected
      }
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}
