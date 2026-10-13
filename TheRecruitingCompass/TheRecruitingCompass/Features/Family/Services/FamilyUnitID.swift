import Foundation

/// The single rule for turning a possibly-missing family id into something safe to send.
/// Encoding `""` into a uuid column fails with Postgres 22P02, so blank means "absent" and the key is omitted.
enum FamilyUnitID {
  static func normalized(_ raw: String?) -> String? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    return trimmed
  }
}
