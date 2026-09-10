import Foundation

/// Form state for creating a new coach inline during interaction creation
struct NewCoachFormState {
  var firstName: String = ""
  var lastName: String = ""
  var email: String = ""
  var role: CoachRole = .assistant

  /// Form is valid if both names are non-empty after trimming whitespace.
  /// Email stays optional on both platforms — no validation on it here.
  var isValid: Bool {
    !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
    !lastName.trimmingCharacters(in: .whitespaces).isEmpty
  }

  /// Get trimmed first name
  var trimmedFirstName: String {
    firstName.trimmingCharacters(in: .whitespaces)
  }

  /// Get trimmed last name
  var trimmedLastName: String {
    lastName.trimmingCharacters(in: .whitespaces)
  }

  /// Get trimmed email
  var trimmedEmail: String {
    email.trimmingCharacters(in: .whitespaces)
  }

  /// Full name for display
  var fullName: String {
    "\(trimmedFirstName) \(trimmedLastName)"
  }

  /// Reset form to default state
  mutating func reset() {
    firstName = ""
    lastName = ""
    email = ""
    role = .assistant
  }

  /// Best-effort split of a draft sender's display name into first/last,
  /// for prefilling the add-coach sheet from an inbound-email draft (#125,
  /// parity w/ web's `splitSenderName` in `AddCoachModal.vue`). First
  /// whitespace-separated token becomes the first name; any remaining
  /// tokens are joined back together as the last name.
  static func splitSenderName(_ senderName: String?) -> (firstName: String, lastName: String) {
    let tokens = (senderName ?? "")
      .split(separator: " ", omittingEmptySubsequences: true)
      .map(String.init)
    guard let first = tokens.first else { return ("", "") }
    return (first, tokens.dropFirst().joined(separator: " "))
  }
}
