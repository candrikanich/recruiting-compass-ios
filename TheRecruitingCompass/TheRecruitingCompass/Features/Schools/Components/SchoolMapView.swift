import SwiftUI
import MapKit

struct SchoolMapView: View {
  let school: School
  let homeLocation: CLLocationCoordinate2D?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Map
      if let lat = school.academicInfo?.latitude,
         let lon = school.academicInfo?.longitude {
        Map {
          Marker(school.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        .mapStyle(.standard)
        .frame(height: 200)
        .cornerRadius(12)
        .accessibilityLabel("Map showing \(school.name) location")

        // Distance from home
        if let distance = calculateDistance() {
          HStack(spacing: 6) {
            Image(systemName: "mappin.and.ellipse")
              .foregroundStyle(.secondary)
              .font(.caption)
              .accessibilityHidden(true)

            Text("Distance from Home: \(Int(distance)) miles")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 4)
        }
      } else {
        // No coordinates available
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
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Location data not available. Use Lookup College Data to fetch location")
      }
    }
  }

  private func calculateDistance() -> Double? {
    guard let homeLoc = homeLocation,
          let lat = school.academicInfo?.latitude,
          let lon = school.academicInfo?.longitude else { return nil }

    let home = CLLocation(latitude: homeLoc.latitude, longitude: homeLoc.longitude)
    let schoolLoc = CLLocation(latitude: lat, longitude: lon)
    return home.distance(from: schoolLoc) / 1609.34 // meters to miles
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
      priorityTier: nil,
      notes: nil,
      privateNotes: nil,
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
      fitScore: nil,
      fitTier: nil,
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
