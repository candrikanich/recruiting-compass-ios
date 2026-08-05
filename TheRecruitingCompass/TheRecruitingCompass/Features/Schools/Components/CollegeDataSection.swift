import SwiftUI

struct CollegeDataSection: View {
  let school: School
  let isLookingUp: Bool
  let lookupError: String?
  let onLookup: () async -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("College Data")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)

        Spacer()

        Button {
          Task { await onLookup() }
        } label: {
          if isLookingUp {
            ProgressView()
              .progressViewStyle(.circular)
              .scaleEffect(0.8)
              .accessibilityLabel(String(localized: "Looking up college data"))
          } else {
            Label("Lookup", systemImage: "magnifyingglass")
              .font(.subheadline)
          }
        }
        .disabled(isLookingUp)
        .frame(minHeight: 44)
        .accessibilityLabel(String(localized: "Lookup college data from College Scorecard"))
      }

      if let error = lookupError {
        HStack(spacing: 8) {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
            .accessibilityHidden(true)

          Text(error)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
      }

      if let info = school.academicInfo {
        VStack(alignment: .leading, spacing: 10) {
          if let size = info.undergradSize {
            InfoRow(label: "Undergrad Size", value: size)
          }

          if let carnegie = info.carnegieSize {
            InfoRow(label: "Carnegie Size", value: carnegie)
          }

          if let admissionRate = info.admissionRate {
            InfoRow(label: "Admission Rate", value: "\(Int(admissionRate * 100))%")
          }

          if let tuitionIn = info.tuitionInState {
            InfoRow(label: "Tuition (In-State)", value: "$\(Int(tuitionIn).formatted())")
          }

          if let tuitionOut = info.tuitionOutOfState {
            InfoRow(label: "Tuition (Out-of-State)", value: "$\(Int(tuitionOut).formatted())")
          }

          if info.undergradSize == nil && info.admissionRate == nil {
            Text("No college data available. Use 'Lookup' to fetch from College Scorecard.")
              .font(.caption)
              .foregroundStyle(.secondary)
              .italic()
              .padding(.vertical, 4)
          }
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }
}

#Preview {
  VStack(spacing: 16) {
    CollegeDataSection(
      school: School(
        id: "1",
        userId: "user1",
        name: "Test University",
        location: "Test, CA",
        city: "Test",
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
          address: nil,
          city: nil,
          state: nil,
          latitude: nil,
          longitude: nil,
          studentSize: nil,
          baseballFacilityAddress: nil,
          mascot: nil,
          undergradSize: "15000",
          carnegieSize: "L",
          tuitionInState: 12000,
          tuitionOutOfState: 45000,
          admissionRate: 0.23,
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
      isLookingUp: false,
      lookupError: nil,
      onLookup: {}
    )
    .padding()
  }
}
