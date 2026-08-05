import SwiftUI

struct EventRow: View {
  let event: FullEvent

  private static let isoParser: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoParserFallback: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private static let dateOnlyParser: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
  }()

  private static let dateOnlyDisplay: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
  }()

  private static let dateTimeDisplay: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  private var eventDateFormatted: String {
    if let date = EventRow.isoParser.date(from: event.startDate)
      ?? EventRow.isoParserFallback.date(from: event.startDate) {
      return EventRow.dateTimeDisplay.string(from: date)
    }
    if let d = EventRow.dateOnlyParser.date(from: event.startDate) {
      return EventRow.dateOnlyDisplay.string(from: d)
    }
    return event.startDate
  }

  private var eventTypeIcon: String {
    switch event.type {
    case "visit", "official_visit", "unofficial_visit": return "building.2"
    case "camp": return "figure.run"
    case "showcase": return "star.circle"
    case "game": return "sportscourt"
    default: return "calendar"
    }
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: eventTypeIcon)
        .font(.title3)
        .foregroundStyle(Color.primaryGreen)
        .frame(width: 32)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text(event.name)
          .font(.subheadline)
          .fontWeight(.semibold)

        Text(eventDateFormatted)
          .font(.caption)
          .foregroundStyle(Color.secondaryText)

        if let location = event.location {
          Text(location)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }

      Spacer()
    }
    .padding(12)
    .frame(minHeight: 44)
    .background(Color(.secondarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(event.type): \(event.name)"))
    .accessibilityValue(eventDateFormatted)
  }
}
