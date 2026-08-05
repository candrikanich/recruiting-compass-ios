import Foundation

enum ActivityEventFactory {
  private static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static func fromInteraction(
    _ interaction: Interaction,
    schoolName: String?
  ) -> ActivityEvent {
    let resolvedSchoolName = schoolName ?? "Unknown School"
    let title = "\(interaction.type.displayName) with \(resolvedSchoolName)"
    let description = String((interaction.content ?? interaction.subject ?? "").prefix(50))
    let timestamp = parseDate(interaction.occurredAt ?? interaction.createdAt)

    return ActivityEvent(
      id: "interaction-\(interaction.id)",
      type: .interaction,
      timestamp: timestamp,
      title: title,
      description: description,
      icon: ActivityIcon.forInteractionType(interaction.type.rawValue),
      entityType: "school",
      entityId: interaction.schoolId,
      entityName: resolvedSchoolName,
      isClickable: true,
      clickUrl: interaction.schoolId.map { "/schools/\($0)" }
    )
  }

  static func fromStatusChange(
    _ history: SchoolStatusHistory,
    schoolName: String?
  ) -> ActivityEvent {
    let resolvedSchoolName = schoolName ?? "Unknown School"
    let formattedStatus = history.newStatus
      .replacing("_", with: " ")
      .capitalized
    let title = "\(resolvedSchoolName) - \(formattedStatus)"
    let description = history.notes ?? "Status changed to \(formattedStatus)"

    return ActivityEvent(
      id: "status-\(history.id)",
      type: .schoolStatusChange,
      timestamp: history.changedAt,
      title: title,
      description: String(description.prefix(50)),
      icon: ActivityIcon.schoolStatus,
      entityType: "school",
      entityId: history.schoolId,
      entityName: resolvedSchoolName,
      isClickable: true,
      clickUrl: "/schools/\(history.schoolId)"
    )
  }

  static func fromDocument(_ document: DocumentRecord) -> ActivityEvent {
    let title = "Uploaded: \(document.title)"
    let docType = document.type ?? "document"
    let description = "New \(docType) uploaded"
    let timestamp = parseDate(document.createdAt)

    return ActivityEvent(
      id: "doc-\(document.id)",
      type: .documentUpload,
      timestamp: timestamp,
      title: title,
      description: description,
      icon: ActivityIcon.document,
      entityType: "document",
      entityId: document.id,
      entityName: document.title,
      isClickable: false,
      clickUrl: nil
    )
  }

  private static func parseDate(_ dateString: String) -> Date {
    iso8601Formatter.date(from: dateString) ?? Date.now
  }
}
