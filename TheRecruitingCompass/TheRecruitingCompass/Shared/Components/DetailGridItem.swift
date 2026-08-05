import SwiftUI

/// Grid item for displaying detail information with optional navigation
struct DetailGridItem: View {
  let title: String
  let value: String
  let icon: String
  var isTappable: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)

        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack {
        Text(value)
          .font(.body)
          .fontWeight(.medium)
          .lineLimit(2)

        if isTappable {
          Spacer()
          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(uiColor: .tertiarySystemBackground))
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "\(title): \(value)"))
    .accessibilityAddTraits(isTappable ? [.isButton] : [])
  }
}

#Preview {
  LazyVGrid(columns: [
    GridItem(.flexible()),
    GridItem(.flexible())
  ], spacing: 16) {
    DetailGridItem(
      title: "School",
      value: "UCLA",
      icon: "building.2",
      isTappable: true
    )

    DetailGridItem(
      title: "Coach",
      value: "John Smith",
      icon: "person",
      isTappable: true
    )

    DetailGridItem(
      title: "Event",
      value: "—",
      icon: "calendar",
      isTappable: false
    )

    DetailGridItem(
      title: "Logged By",
      value: "You",
      icon: "person.circle",
      isTappable: false
    )
  }
  .padding()
}
