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
