import Foundation
import Combine

struct CountdownTimerConfig {
  let initialValue: Int
  let interval: TimeInterval
  let onTick: (Int) -> Void
  let onCompletion: () -> Void
}

func startCountdownTimer(config: CountdownTimerConfig) -> AnyCancellable {
  var remaining = config.initialValue

  return Timer.publish(every: config.interval, on: .main, in: .common)
    .autoconnect()
    .sink { _ in
      remaining -= 1
      config.onTick(remaining)

      if remaining <= 0 {
        config.onCompletion()
      }
    }
}
