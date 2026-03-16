import Foundation

enum FormValidator {
  // MARK: - Email
  private static let emailRegex = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/

  static func validateEmail(_ email: String) -> String? {
    let trimmed = email.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "Email is required" }
    guard trimmed.wholeMatch(of: emailRegex) != nil else { return "Invalid email address" }
    return nil
  }

  // MARK: - Password
  static func validatePassword(_ password: String) -> String? {
    guard !password.isEmpty else { return "Password is required" }
    guard password.count >= 8 else { return "Password must be at least 8 characters" }
    return nil
  }

  static func validatePasswordStrength(_ password: String) -> (isValid: Bool, errors: [String]) {
    var errors: [String] = []
    if password.count < 8 { errors.append("at least 8 characters") }
    if !password.contains(where: { $0.isUppercase }) { errors.append("an uppercase letter") }
    if !password.contains(where: { $0.isLowercase }) { errors.append("a lowercase letter") }
    if !password.contains(where: { $0.isNumber }) { errors.append("a number") }
    return (isValid: errors.isEmpty, errors: errors)
  }

  static func validatePasswordMatch(_ password: String, _ confirmPassword: String) -> String? {
    guard password == confirmPassword else { return "Passwords do not match" }
    return nil
  }

  // MARK: - Name
  private static let nameRegex = /^[a-zA-Z\s\-']+$/

  static func validateName(_ name: String) -> String? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "Name is required" }
    guard trimmed.count >= 2 else { return "Name must be at least 2 characters" }
    guard trimmed.wholeMatch(of: nameRegex) != nil else {
      return "Name can only contain letters, spaces, hyphens, and apostrophes"
    }
    return nil
  }

  // MARK: - Family Code
  private static let familyCodeRegex = /^FAM-[A-Z0-9]{6}$/

  static func validateFamilyCode(_ code: String?) -> String? {
    guard let code else { return nil }
    let trimmed = code.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.wholeMatch(of: familyCodeRegex) != nil else {
      return "Family code must be in format FAM-XXXXXX"
    }
    return nil
  }
}
