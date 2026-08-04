import Foundation

struct TemplateVariable {
  let name: String
  let key: String

  static let all: [TemplateVariable] = [
    TemplateVariable(name: "Coach Name", key: "coach_name"),
    TemplateVariable(name: "Athlete Name", key: "athlete_name"),
    TemplateVariable(name: "School Name", key: "school_name"),
    TemplateVariable(name: "Sport", key: "sport"),
    TemplateVariable(name: "Position", key: "position"),
    TemplateVariable(name: "Graduation Year", key: "grad_year"),
    TemplateVariable(name: "High School", key: "high_school")
  ]
}
