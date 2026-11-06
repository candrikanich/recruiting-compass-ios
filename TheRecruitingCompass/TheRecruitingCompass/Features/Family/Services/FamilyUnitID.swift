import Foundation

/// The single rule for turning a possibly-missing family id into something safe to send.
/// Encoding `""` into a uuid column fails with Postgres 22P02, so blank means "absent".
enum FamilyUnitID {
  /// A missing family is an invariant violation (web#1237): create paths surface this and refuse to write,
  /// they never fall back to `""` or silently skip the family column.
  enum MissingError: LocalizedError, Equatable {
    case missing

    var errorDescription: String? {
      String(localized: "Your family account is still loading. Please wait a moment and try again.")
    }
  }

  static func normalized(_ raw: String?) -> String? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    return trimmed
  }

  /// The id to stamp on an insert payload, or `MissingError` when there is no real family.
  static func require(_ raw: String?) throws -> String {
    guard let id = normalized(raw) else { throw MissingError.missing }
    return id
  }
}
