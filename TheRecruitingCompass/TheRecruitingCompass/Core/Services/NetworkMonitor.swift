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
      let connected = path.status == .satisfied
      Task { @MainActor [weak self] in
        self?.isConnected = connected
      }
    }
    monitor.start(queue: queue)
  }

  nonisolated deinit {
    monitor.cancel()
  }
}
