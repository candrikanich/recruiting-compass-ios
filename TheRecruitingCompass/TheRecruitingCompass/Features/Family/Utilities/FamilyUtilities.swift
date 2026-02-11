import Foundation

enum FamilyUtilities {
  static func formatCodeForVoiceOver(_ code: String) -> String {
    let parts = code.split(separator: "-")
    guard parts.count == 2 else { return code }
    let prefix = String(parts[0])
    let digits = String(parts[1]).map { String($0) }.joined(separator: " ")
    return "\(prefix) dash \(digits)"
  }
}

extension DateFormatter {
  static let familyCodeDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  static let memberJoinDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()
}
