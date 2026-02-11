import Foundation

/// Form state for creating a new coach inline during interaction creation
struct NewCoachFormState {
  var firstName: String = ""
  var lastName: String = ""
  var role: CoachRole = .assistant

  /// Form is valid if both names are non-empty after trimming whitespace
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

  /// Full name for display
  var fullName: String {
    "\(trimmedFirstName) \(trimmedLastName)"
  }

  /// Reset form to default state
  mutating func reset() {
    firstName = ""
    lastName = ""
    role = .assistant
  }
}
