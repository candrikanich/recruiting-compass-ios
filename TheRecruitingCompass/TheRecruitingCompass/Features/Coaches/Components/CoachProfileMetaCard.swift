import SwiftUI

/// Profile meta rows (Coach Since / Source / Last Updated) — matching the frame.
struct CoachProfileMetaCard: View {
  let coach: Coach

  private static let displayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d, yyyy"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  private static let isoWithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
  }()

  private static let isoWithoutFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
  }()

  private func formatted(_ iso: String) -> String {
    let date = Self.isoWithFractional.date(from: iso) ?? Self.isoWithoutFractional.date(from: iso)
    return date.map { Self.displayFormatter.string(from: $0) } ?? iso
  }

  var body: some View {
    VStack(spacing: 8) {
      row(label: "Coach Since", value: formatted(coach.createdAt))
      row(label: "Source", value: coach.source ?? "—")
      row(label: "Last Updated", value: formatted(coach.updatedAt))
    }
  }

  @ViewBuilder
  private func row(label: LocalizedStringKey, value: String) -> some View {
    HStack {
      Text(label).font(.subheadline).foregroundStyle(.secondary)
      Spacer()
      Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
    }
    .accessibilityElement(children: .combine)
  }
}
