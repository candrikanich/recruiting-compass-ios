import Foundation

/// Maps sports to their NCAA gender classification. Male-only, female-only,
/// or neutral/both-gender sports. Used during onboarding to auto-derive gender
/// from primary sport selection, reducing friction.
enum SportGender {
  case male
  case female
  case neutral

  var genderRawValue: String? {
    switch self {
    case .male: return Gender.male.rawValue
    case .female: return Gender.female.rawValue
    case .neutral: return nil
    }
  }
}

enum SportGenderMap {
  private static let maleSports: Set<String> = [
    "Baseball", "Football", "Wrestling"
  ]

  private static let femaleSports: Set<String> = [
    "Softball", "Field Hockey", "Volleyball", "Beach Volleyball"
  ]

  /// Lacrosse classification depends on the specific variant (men's vs women's).
  /// Since we store just "Lacrosse" without a qualifier, treat it as neutral.
  /// All other sports (track, swimming, tennis, soccer, basketball, golf,
  /// cross country, ice hockey, rowing, water polo, gymnastics) are co-ed.

  static func gender(for sport: String) -> SportGender {
    let trimmed = sport.trimmingCharacters(in: .whitespaces)
    if maleSports.contains(trimmed) { return .male }
    if femaleSports.contains(trimmed) { return .female }
    return .neutral
  }
}
