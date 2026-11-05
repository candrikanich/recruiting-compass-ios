import Foundation

/// Holds async calls until `open()` so a test can interleave work with an in-flight request.
/// Only the first `blockedEntries` callers wait; later callers pass straight through, which lets
/// a test hold one stale request while a newer one completes.
///
/// Both ends are bounded by `timeout`: a waiter the test never releases opens the gate itself, and
/// `untilEntered` gives up when nobody arrives. A wrong outcome then fails on the test's own assertions
/// instead of stalling the run until `run-ios-tests.sh` kills it (#530).
@MainActor
final class AsyncGate {
  nonisolated deinit {}

  private(set) var enteredCount = 0
  private let blockedEntries: Int
  private let timeout: Duration
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(blockedEntries: Int = .max, timeout: Duration = .seconds(5)) {
    self.blockedEntries = blockedEntries
    self.timeout = timeout
  }

  func wait() async {
    enteredCount += 1
    guard !isOpen, enteredCount <= blockedEntries else { return }
    let timeout = timeout
    let watchdog = Task { [weak self] in
      try? await Task.sleep(for: timeout)
      self?.open()
    }
    await withCheckedContinuation { waiters.append($0) }
    watchdog.cancel()
  }

  func open() {
    isOpen = true
    waiters.forEach { $0.resume() }
    waiters = []
  }

  /// Returns false when `count` callers never arrived within the timeout.
  @discardableResult
  func untilEntered(_ count: Int = 1) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while enteredCount < count {
      guard ContinuousClock.now < deadline else { return false }
      await Task.yield()
    }
    return true
  }
}
