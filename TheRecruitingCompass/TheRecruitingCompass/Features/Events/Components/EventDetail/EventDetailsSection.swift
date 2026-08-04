import SwiftUI

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
