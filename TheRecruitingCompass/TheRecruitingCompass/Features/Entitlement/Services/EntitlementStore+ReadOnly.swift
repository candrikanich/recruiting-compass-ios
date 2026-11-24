extension EntitlementStore {
  /// True only when the family's plan is known and does not allow writes. `canWrite` alone reads `false` while the
  /// plan is still loading or failed to load, and a gate on that would lock out a family the server would let write.
  /// `subscription` is nil in those cases, and already nil for a family other than the selected one.
  var isReadOnly: Bool {
    subscription != nil && !canWrite
  }
}
