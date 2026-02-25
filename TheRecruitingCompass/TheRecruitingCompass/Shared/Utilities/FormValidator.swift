import Foundation

enum FormValidator {
  // Email regex pattern (RFC 5322 simplified)
  private static let emailPattern = "^[a-zA-Z0-9._%+\\-]+@[a-zA-Z0-9.\\-]+\\.[a-zA-Z]{2,}$"
  // Family code pattern: FAM-XXXXXXXX (alphanumeric after prefix)
  private static let familyCodePattern = "^FAM-[A-Z0-9]{8}$"

  private static let emailRegex: NSRegularExpression = try! NSRegularExpression(pattern: emailPattern)
  private static let familyCodeRegex: NSRegularExpression = try! NSRegularExpression(pattern: familyCodePattern)

  static func validateEmail(_ email: String) -> String? {
    let trimmed = email.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty else {
      return "Email is required"
    }

    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard emailRegex.firstMatch(in: trimmed, range: range) != nil else {
      return "Invalid email address"
    }

    return nil
  }

  static func validatePassword(_ password: String) -> String? {
    guard !password.isEmpty else {
      return "Password is required"
    }

    guard password.count >= 8 else {
      return "Password must be at least 8 characters"
    }

    return nil
  }

  private static let nameRegex: NSRegularExpression = try! NSRegularExpression(pattern: "^[a-zA-Z\\s\\-']+$")

  static func validateName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty else {
      return "Name is required"
    }

    guard trimmed.count >= 2 else {
      return "Name must be at least 2 characters"
    }

    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard nameRegex.firstMatch(in: trimmed, range: range) != nil else {
      return "Name can only contain letters, spaces, hyphens, and apostrophes"
    }

    return nil
  }

  static func validatePasswordStrength(_ password: String) -> (isValid: Bool, errors: [String]) {
    var errors: [String] = []

    if password.count < 8 {
      errors.append("at least 8 characters")
    }

    if !password.contains(where: { $0.isUppercase }) {
      errors.append("an uppercase letter")
    }

    if !password.contains(where: { $0.isLowercase }) {
      errors.append("a lowercase letter")
    }

    if !password.contains(where: { $0.isNumber }) {
      errors.append("a number")
    }

    return (isValid: errors.isEmpty, errors: errors)
  }

  static func validatePasswordMatch(_ password: String, _ confirmPassword: String) -> String? {
    guard password == confirmPassword else {
      return "Passwords do not match"
    }

    return nil
  }

  static func validateFamilyCode(_ code: String?) -> String? {
    guard let code = code else {
      return nil // Optional field
    }

    let trimmed = code.trimmingCharacters(in: .whitespaces)

    guard !trimmed.isEmpty else {
      return nil // Empty is acceptable for optional field
    }

    let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)

    guard familyCodeRegex.firstMatch(in: trimmed, range: range) != nil else {
      return "Family code must be in format FAM-XXXXXXXX"
    }

    return nil
  }
}
