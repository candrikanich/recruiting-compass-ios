import SwiftUI

struct EventLocationSection: View {
  let event: FullEvent
  let formattedLocation: String?
  let hasLocation: Bool
  let getDirectionsURL: () -> URL?

  var body: some View {
    Section {
      if let address = event.address, !address.isEmpty {
        Label(address, systemImage: "mappin")
          .accessibilityLabel(String(localized: "Address: \(address)"))
      }
      if let locationLine = formattedLocation {
        Label(locationLine, systemImage: "location")
          .accessibilityLabel(String(localized: "Location: \(locationLine)"))
      }
      if let venueName = event.location, !venueName.isEmpty {
        Label(venueName, systemImage: "building.2")
          .accessibilityLabel(String(localized: "Venue: \(venueName)"))
      }
      if hasLocation {
        Button {
          if let url = getDirectionsURL() { UIApplication.shared.open(url) }
        } label: {
          Label("Get Directions", systemImage: "map")
        }
        .accessibilityLabel(String(localized: "Get directions to \(event.location ?? "event location")"))
        .accessibilityHint("Opens Apple Maps")
      }
    } header: {
      Text("Location")
    }
  }
}
