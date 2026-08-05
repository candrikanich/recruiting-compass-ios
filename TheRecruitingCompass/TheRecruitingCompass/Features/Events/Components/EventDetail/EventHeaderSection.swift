import SwiftUI

struct EventHeaderSection: View {
  let event: FullEvent
  let formattedDateRange: String
  let formattedCost: String?
  let costAccessibilityLabel: String?

  var body: some View {
    Section {
      HStack {
        EventTypeBadge(type: event.type)
        Spacer()
        EventStatusBadge(registered: event.registered, attended: event.attended)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel(String(localized: "\(event.name), \(EventType(rawValue: event.type)?.displayName ?? event.type), \(formattedDateRange), \(statusLabel)"))

      Label(formattedDateRange, systemImage: "calendar")
        .accessibilityLabel(String(localized: "Date: \(formattedDateRange)"))
      if let startTime = event.startTime, !startTime.isEmpty {
        Label(timeRange(start: startTime, end: event.endTime), systemImage: "clock")
          .accessibilityLabel(String(localized: "Time: \(timeRange(start: startTime, end: event.endTime))"))
      }
      if let checkinTime = event.checkinTime, !checkinTime.isEmpty {
        Label("Check-in: \(checkinTime)", systemImage: "checkmark.circle")
          .accessibilityLabel(String(localized: "Check-in time: \(checkinTime)"))
      }
      if let costText = formattedCost {
        Label(costText, systemImage: "dollarsign.circle")
          .accessibilityLabel(costAccessibilityLabel ?? "")
      }
      if let source = event.eventSource, !source.isEmpty {
        Label(EventSource(rawValue: source)?.displayName ?? source, systemImage: "pin")
          .foregroundStyle(.secondary)
          .accessibilityLabel(String(localized: "Source: \(EventSource(rawValue: source)?.displayName ?? source)"))
      }
    } header: {
      Text("Event Info")
    }
  }

  private var statusLabel: String {
    if event.attended { return "Attended" }
    if event.registered { return "Registered" }
    return "Not Registered"
  }

  private func timeRange(start: String, end: String?) -> String {
    guard let end, !end.isEmpty else { return start }
    return "\(start) – \(end)"
  }
}
