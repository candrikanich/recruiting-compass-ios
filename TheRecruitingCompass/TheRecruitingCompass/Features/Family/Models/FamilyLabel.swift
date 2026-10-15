import Foundation

/// The server owns the "<Player>'s Family" rule (web `resolveFamilyLabels`, which also guarantees an email address
/// is never shown as a name). iOS only displays what it is given and never derives a label from a user's name.
enum FamilyLabel {
  /// The server's `familyLabel` when present and non-blank, otherwise the legacy `familyName` (old prod builds of
  /// the API don't send `familyLabel` yet).
  static func display(label: String?, legacyName: String?) -> String? {
    [label, legacyName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
  }
}

/// Response from `POST /api/family/code/join`. Every field is optional: the join itself already succeeded when the
/// server returned 2xx, so a body we can't read must never turn that into a failure.
struct JoinFamilyResponse: Codable, Sendable, Equatable {
  let familyId: String?
  let familyName: String?
  let familyLabel: String?

  var displayLabel: String? { FamilyLabel.display(label: familyLabel, legacyName: familyName) }
}
