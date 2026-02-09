import Foundation

enum EntityNameLookup {
  static func schoolNameMap(from schools: [School]) -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: schools.map { ($0.id, $0.name) }
    )
  }

  static func coachNameMap(from coaches: [Coach]) -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: coaches.map { ($0.id, $0.fullName) }
    )
  }

  static func schoolName(for schoolId: String?, in nameMap: [String: String]) -> String {
    guard let schoolId else { return "Unknown School" }
    return nameMap[schoolId] ?? "Unknown School"
  }

  static func coachName(for coachId: String?, in nameMap: [String: String]) -> String {
    guard let coachId else { return "Unknown Coach" }
    return nameMap[coachId] ?? "Unknown Coach"
  }
}
