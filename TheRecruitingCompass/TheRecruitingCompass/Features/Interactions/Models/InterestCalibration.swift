import Foundation

/// Interest calibration data for inbound positive interactions
struct InterestCalibration {
  /// Standard questions to assess coach interest level
  static let questions: [String] = [
    "Did they ask about your schedule or upcoming events?",
    "Did they mention visiting campus or suggest a visit?",
    "Did they ask about your academic interests or major?",
    "Did they provide their direct contact info (phone/email)?",
    "Did they mention roster needs at your position?",
    "Was this a personalized response (not a form letter)?"
  ]

  /// Answers to the calibration questions (true = yes, false = no)
  var answers: [Bool] = Array(repeating: false, count: 6)

  /// Number of yes answers
  var yesCount: Int {
    answers.count(where: { $0 })
  }

  /// Computed interest level based on yes count
  var interestLevel: InterestLevel {
    switch yesCount {
    case 0: return .notSet
    case 1: return .low
    case 2...3: return .medium
    default: return .high
    }
  }

  /// Description of the interest level result
  var resultDescription: String {
    switch interestLevel {
    case .notSet:
      return "Answer questions to see coach interest level"
    case .low:
      return "Limited signals detected. Consider diversifying your target list."
    case .medium:
      return "Coach seems interested but check for personalization. Stay in touch regularly."
    case .high:
      return "Coach showing strong signals of genuine interest. Follow up promptly."
    }
  }

  /// Reset all answers to false
  mutating func reset() {
    answers = Array(repeating: false, count: 6)
  }
}
