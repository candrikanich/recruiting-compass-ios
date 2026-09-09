import Foundation

/// Groups `CommunicationTemplate.stage` into display order + labels. Ports web's
/// `utils/communication/templateStages.ts` byte-for-byte (#114, web parity with #519 / PR #721).
enum TemplateStage {
  /// Human label for each `communication_templates.stage` value (DB CHECK constraint in
  /// migration 20260816000000). Order here is display order — a narrative arc through the
  /// outreach lifecycle, not alphabetical or DB insertion order.
  static let labels: [String: String] = [
    "intro": "First Contact",
    "reply": "Replying to a Coach",
    "update": "Sharing an Update",
    "event": "Events & Schedule",
    "post_event": "After an Event",
    "visit": "Visits",
    "thanks": "Thank You",
    "status": "Where You Stand",
    "decision": "Offers & Decisions",
    "nudge": "Following Up",
    "social": "Announcements",
  ]

  static let order: [String] = [
    "intro", "reply", "update", "event", "post_event",
    "visit", "thanks", "status", "decision", "nudge", "social",
  ]

  /// Templates with no stage (user-authored, or a future predefined row not yet
  /// categorized) land in this trailing group rather than disappearing from the picker.
  static let otherLabel = "Other"
}

struct TemplateStageGroup: Equatable {
  let stage: String?
  let label: String
  let templates: [CommunicationTemplate]

  static func == (lhs: TemplateStageGroup, rhs: TemplateStageGroup) -> Bool {
    lhs.stage == rhs.stage && lhs.label == rhs.label && lhs.templates.map(\.id) == rhs.templates.map(\.id)
  }
}

/// Groups templates by `stage` in a fixed narrative order (`TemplateStage.order`), each
/// group's templates alphabetized by name. Unstaged/unrecognized-stage templates form one
/// trailing "Other" group instead of being dropped.
func groupTemplatesByStage(_ templates: [CommunicationTemplate]) -> [TemplateStageGroup] {
  var byStage: [String: [CommunicationTemplate]] = [:]
  var other: [CommunicationTemplate] = []

  for template in templates {
    guard let stage = template.stage, TemplateStage.labels[stage] != nil else {
      other.append(template)
      continue
    }
    byStage[stage, default: []].append(template)
  }

  let byName: (CommunicationTemplate, CommunicationTemplate) -> Bool = { $0.name < $1.name }

  var groups = TemplateStage.order.compactMap { stage -> TemplateStageGroup? in
    guard let bucket = byStage[stage] else { return nil }
    return TemplateStageGroup(stage: stage, label: TemplateStage.labels[stage]!, templates: bucket.sorted(by: byName))
  }

  if !other.isEmpty {
    groups.append(TemplateStageGroup(stage: nil, label: TemplateStage.otherLabel, templates: other.sorted(by: byName)))
  }

  return groups
}
