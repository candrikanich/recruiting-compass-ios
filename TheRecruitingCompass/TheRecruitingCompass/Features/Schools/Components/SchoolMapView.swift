import SwiftUI
import MapKit

struct SchoolMapView: View {
  let school: School
  let homeLocation: CLLocationCoordinate2D?
  var onSetHomeLocation: () -> Void = {}

  enum MapState: Equatable {
    case distance(String)
    case setHomeCTA
    case noSchoolCoords
  }

  /// Testable view state derived from the school + home coordinates.
  var mapState: MapState {
    guard let lat = school.academicInfo?.latitude,
          let lon = school.academicInfo?.longitude else {
      return .noSchoolCoords
    }
    guard let home = homeLocation else {
      return .setHomeCTA
    }
    let miles = DistanceCalculator.milesRounded(
      from: home,
      to: CLLocationCoordinate2D(latitude: lat, longitude: lon)
    )
    return .distance(DistanceCalculator.formatMiles(miles))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if let lat = school.academicInfo?.latitude,
         let lon = school.academicInfo?.longitude {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let region = MKCoordinateRegion(
          center: coordinate,
          span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
        Map(initialPosition: .region(region)) {
          Marker(school.name, coordinate: coordinate)
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityLabel(String(localized: "Map showing \(school.name) location"))
        .accessibilityAddTraits(.allowsDirectInteraction)
        .accessibilityHint("Use two fingers to pan and pinch to zoom the map")

        switch mapState {
        case .distance(let label):
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
              .foregroundStyle(.secondary)
              .font(.caption)
              .accessibilityHidden(true)

            Text("Distance from Home: \(label)")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 4)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(String(localized: "Distance from Home: \(label)"))

        case .setHomeCTA:
          Button(action: onSetHomeLocation) {
            HStack(spacing: 6) {
              Image(systemName: "mappin.and.ellipse")
                .font(.caption)
                .accessibilityHidden(true)
              Text("Set your home location to see distance")
                .font(.subheadline)
            }
            .frame(minHeight: 44)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.tint)
          .padding(.top, 4)
          .accessibilityLabel(String(localized: "Set your home location to see distance to schools"))
          .accessibilityAddTraits(.isButton)

        case .noSchoolCoords:
          EmptyView()
        }
      } else {
        VStack(spacing: 8) {
          Image(systemName: "map")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)

          Text("Location data not available")
            .font(.subheadline)
            .foregroundStyle(.secondary)

          Text("Use 'Lookup College Data' to fetch location")
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(.rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Location data not available. Use Lookup College Data to fetch location"))
      }
    }
  }
}

#Preview {
  SchoolMapView(
    school: School(
      id: "1",
      userId: "user1",
      name: "Stanford University",
      location: "Stanford, CA",
      city: "Stanford",
      state: "CA",
      division: "D1",
      conference: "Pac-12",
      ranking: nil,
      isFavorite: false,
      website: nil,
      faviconUrl: nil,
      twitterHandle: nil,
      instagramHandle: nil,
      ncaaId: nil,
      status: "interested",
      statusChangedAt: nil,
      notes: nil,
      pros: [],
      cons: [],
      offerDetails: nil,
      academicInfo: AcademicInfo(
        gpaRequirement: nil,
        satRequirement: nil,
        actRequirement: nil,
        additionalRequirements: nil,
        address: "450 Serra Mall",
        city: "Stanford",
        state: "CA",
        latitude: 37.4275,
        longitude: -122.1697,
        studentSize: nil,
        baseballFacilityAddress: nil,
        mascot: nil,
        undergradSize: nil,
        carnegieSize: nil,
        tuitionInState: nil,
        tuitionOutOfState: nil,
        admissionRate: nil,
        distanceFromHome: nil
      ),
      amenities: nil,
      coachingPhilosophy: nil,
      coachingStyle: nil,
      recruitingApproach: nil,
      communicationStyle: nil,
      successMetrics: nil,
      familyUnitId: "family1",
      createdBy: nil,
      updatedBy: nil,
      createdAt: "2025-01-01T00:00:00Z",
      updatedAt: "2025-01-01T00:00:00Z"
    ),
    homeLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194) // SF
  )
  .padding()
}
