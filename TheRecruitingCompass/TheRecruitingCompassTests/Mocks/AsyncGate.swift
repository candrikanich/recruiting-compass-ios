import Foundation

/// Holds async calls until `open()` so a test can interleave work with an in-flight request.
/// Only the first `blockedEntries` callers wait; later callers pass straight through, which lets
/// a test hold one stale request while a newer one completes.
@MainActor
final class AsyncGate {
  nonisolated deinit {}

  private(set) var enteredCount = 0
  private let blockedEntries: Int
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  init(blockedEntries: Int = .max) {
    self.blockedEntries = blockedEntries
  }

  func wait() async {
    enteredCount += 1
    guard !isOpen, enteredCount <= blockedEntries else { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  func open() {
    isOpen = true
    waiters.forEach { $0.resume() }
    waiters = []
  }

  func untilEntered(_ count: Int = 1) async {
    while enteredCount < count { await Task.yield() }
  }
}
