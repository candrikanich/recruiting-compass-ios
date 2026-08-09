import SwiftUI

struct EventRowView: View {
  let event: FullEvent

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        typeBadge
        statusBadge
        Spacer()
      }

      Text(event.name)
        .font(.headline)
        .lineLimit(2)

      Label(formattedDate, systemImage: "calendar")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      if let time = event.startTime, !time.isEmpty {
        Label(time, systemImage: "clock")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let location = locationLine {
        Label(location, systemImage: "mappin")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      if let cost = event.cost, cost > 0 {
        Label(cost.formatted(.currency(code: "USD")), systemImage: "dollarsign.circle")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      if let notes = event.performanceNotes, !notes.isEmpty {
        Text(notes)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .padding(.top, 2)
      }
    }
    .padding(.vertical, 4)
  }

  @ViewBuilder
  private var typeBadge: some View {
    let eventType = EventType(rawValue: event.type)
    return Text(eventType?.displayName ?? event.type)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(typeColor.opacity(0.15))
      .foregroundStyle(typeColor)
      .clipShape(Capsule())
  }

  @ViewBuilder
  private var statusBadge: some View {
    let label = event.attended
      ? String(localized: "Attended")
      : event.registered ? String(localized: "Registered") : String(localized: "Not Registered")
    let color: Color = event.attended ? .green : event.registered ? .blue : .gray
    return Text(label)
      .font(.caption)
      .fontWeight(.semibold)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.12))
      .foregroundStyle(color)
      .clipShape(Capsule())
  }

  private var typeColor: Color {
    switch EventType(rawValue: event.type) {
    case .showcase: return .purple
    case .camp: return .green
    case .officialVisit: return .blue
    case .unofficialVisit: return .cyan
    case .game: return .orange
    case nil: return .gray
    }
  }

  private var formattedDate: String {
    DateFormatting.isoDateRangeString(from: event.startDate, to: event.endDate)
  }

  private var locationLine: String? {
    var parts: [String] = []
    if let city = event.city, !city.isEmpty { parts.append(city) }
    if let state = event.state, !state.isEmpty { parts.append(state) }
    return parts.isEmpty ? nil : parts.joined(separator: ", ")
  }
}
