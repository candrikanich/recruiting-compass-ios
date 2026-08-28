import Foundation

struct EditableCoachingPhilosophy: Sendable {
  var coachingPhilosophy: String
  var coachingStyle: String
  var recruitingApproach: String
  var communicationStyle: String
  var successMetrics: String

  init(
    coachingPhilosophy: String = "",
    coachingStyle: String = "",
    recruitingApproach: String = "",
    communicationStyle: String = "",
    successMetrics: String = ""
  ) {
    self.coachingPhilosophy = coachingPhilosophy
    self.coachingStyle = coachingStyle
    self.recruitingApproach = recruitingApproach
    self.communicationStyle = communicationStyle
    self.successMetrics = successMetrics
  }

  static func from(school: School) -> EditableCoachingPhilosophy {
    EditableCoachingPhilosophy(
      coachingPhilosophy: school.coachingPhilosophy ?? "",
      coachingStyle: school.coachingStyle ?? "",
      recruitingApproach: school.recruitingApproach ?? "",
      communicationStyle: school.communicationStyle ?? "",
      successMetrics: school.successMetrics ?? ""
    )
  }
}
