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
      .accessibilityLabel("\(event.name), \(EventType(rawValue: event.type)?.displayName ?? event.type), \(formattedDateRange), \(statusLabel)")

      Label(formattedDateRange, systemImage: "calendar")
        .accessibilityLabel("Date: \(formattedDateRange)")
      if let startTime = event.startTime, !startTime.isEmpty {
        Label(timeRange(start: startTime, end: event.endTime), systemImage: "clock")
          .accessibilityLabel("Time: \(timeRange(start: startTime, end: event.endTime))")
      }
      if let checkinTime = event.checkinTime, !checkinTime.isEmpty {
        Label("Check-in: \(checkinTime)", systemImage: "checkmark.circle")
          .accessibilityLabel("Check-in time: \(checkinTime)")
      }
      if let costText = formattedCost {
        Label(costText, systemImage: "dollarsign.circle")
          .accessibilityLabel(costAccessibilityLabel ?? "")
      }
      if let source = event.eventSource, !source.isEmpty {
        Label(EventSource(rawValue: source)?.displayName ?? source, systemImage: "pin")
          .foregroundStyle(.secondary)
          .accessibilityLabel("Source: \(EventSource(rawValue: source)?.displayName ?? source)")
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

struct EventLocationSection: View {
  let event: FullEvent
  let formattedLocation: String?
  let hasLocation: Bool
  let getDirectionsURL: () -> URL?

  var body: some View {
    Section {
      if let address = event.address, !address.isEmpty {
        Label(address, systemImage: "mappin")
          .accessibilityLabel("Address: \(address)")
      }
      if let locationLine = formattedLocation {
        Label(locationLine, systemImage: "location")
          .accessibilityLabel("Location: \(locationLine)")
      }
      if let venueName = event.location, !venueName.isEmpty {
        Label(venueName, systemImage: "building.2")
          .accessibilityLabel("Venue: \(venueName)")
      }
      if hasLocation {
        Button {
          if let url = getDirectionsURL() { UIApplication.shared.open(url) }
        } label: {
          Label("Get Directions", systemImage: "map")
        }
        .accessibilityLabel("Get directions to \(event.location ?? "event location")")
        .accessibilityHint("Opens Apple Maps")
      }
    } header: {
      Text("Location")
    }
  }
}

struct EventDetailsSection: View {
  private enum Layout {
    static let descriptionSpacing: CGFloat = 4
  }

  let event: FullEvent

  var body: some View {
    Section {
      if let description = event.description, !description.isEmpty {
        VStack(alignment: .leading, spacing: Layout.descriptionSpacing) {
          Text("Description").font(.caption).foregroundStyle(.secondary)
          Text(description).font(.body)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Description: \(description)")
      }
      if let url = event.url, !url.isEmpty, let linkURL = URL(string: url) {
        Link(url, destination: linkURL)
          .accessibilityLabel("Event link: \(url)")
      }
    } header: {
      Text("Details")
    }
  }
}

struct EventPerformanceSection: View {
  let event: FullEvent

  var body: some View {
    Section {
      if let notes = event.performanceNotes, !notes.isEmpty {
        Text(notes)
          .accessibilityLabel("Performance notes: \(notes)")
      }
    } header: {
      Text("Performance Notes")
    }
  }
}
