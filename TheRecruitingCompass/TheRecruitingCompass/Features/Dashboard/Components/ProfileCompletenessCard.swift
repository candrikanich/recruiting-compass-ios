import SwiftUI

struct ProfileCompletenessCard: View {
  let percentage: Double
  let missingFields: [MissingField]

  @Environment(\.openMoreSection) private var openMoreSection

  var body: some View {
    if percentage < 0.80 {
      expandedCard
    } else if percentage < 1.0 {
      compactBar
    }
  }

  // MARK: - Expanded Card (< 80%)

  @ViewBuilder
  private var expandedCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 16) {
        progressRing

        VStack(alignment: .leading, spacing: 4) {
          Text("Complete Your Profile")
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

          Text("A complete profile helps coaches find you")
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
        }
      }

      if !missingFields.isEmpty {
        Divider()

        VStack(spacing: 0) {
          ForEach(missingFields.prefix(3)) { field in
            Button {
              openMoreSection(.settings)
            } label: {
              HStack(spacing: 10) {
                Image(systemName: field.icon)
                  .foregroundStyle(Color.accentBlue)
                  .frame(width: 20)
                  .accessibilityHidden(true)

                Text(field.label)
                  .font(.subheadline)
                  .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption2)
                  .foregroundStyle(Color.secondaryText)
                  .accessibilityHidden(true)
              }
              .padding(.vertical, 8)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "Add \(field.label)"))
            .accessibilityHint(String(localized: "Opens player details"))
          }
        }
      }
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
  }

  @ViewBuilder
  private var progressRing: some View {
    ZStack {
      Circle()
        .stroke(Color.Surface.muted, lineWidth: 6)

      Circle()
        .trim(from: 0, to: percentage)
        .stroke(
          ringColor,
          style: StrokeStyle(lineWidth: 6, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.easeInOut(duration: 0.5), value: percentage)

      Text("\(Int(percentage * 100))%")
        .font(.caption.bold())
        .foregroundStyle(ringColor)
    }
    .frame(width: 56, height: 56)
    .accessibilityLabel(String(localized: "Profile \(Int(percentage * 100)) percent complete"))
  }

  private var ringColor: Color {
    if percentage >= 0.80 { return Color.successGreen }
    if percentage >= 0.50 { return Color.amberGold }
    return Color.Brand.blue600
  }

  // MARK: - Compact Bar (>= 80%)

  @ViewBuilder
  private var compactBar: some View {
    HStack(spacing: 12) {
      Image(systemName: "checkmark.seal.fill")
        .foregroundStyle(Color.successGreen)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 4) {
        Text("Profile \(Int(percentage * 100))% Complete")
          .font(.subheadline.weight(.semibold))

        Text("Great progress!")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
      }

      Spacer()

      ProgressView(value: percentage, total: 1.0)
        .tint(Color.successGreen)
        .frame(width: 60)
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Profile \(Int(percentage * 100)) percent complete. Great progress!"))
  }
}

// MARK: - Missing Field Model

struct MissingField: Identifiable {
  let id: String
  let label: String
  let icon: String
}

extension PlayerDetails {
  /// Returns up to `limit` missing profile fields, ordered by weight (highest first).
  func topMissingFields(
    hasHighlightVideo: Bool,
    hasHomeLocation: Bool,
    limit: Int = 3
  ) -> [MissingField] {
    func filled(_ s: String?) -> Bool {
      !(s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var missing: [MissingField] = []

    // Ordered by weight descending
    if gpa == nil {
      missing.append(MissingField(id: "gpa", label: String(localized: "GPA"), icon: "graduationcap"))
    }
    if !hasHighlightVideo {
      missing.append(MissingField(id: "video", label: String(localized: "Highlight video"), icon: "play.rectangle"))
    }
    if graduationYear == nil {
      missing.append(MissingField(id: "gradYear", label: String(localized: "Graduation year"), icon: "calendar"))
    }
    if !filled(primarySport) {
      missing.append(MissingField(id: "sport", label: String(localized: "Primary sport"), icon: "sportscourt"))
    }
    if !filled(primaryPosition) {
      missing.append(MissingField(id: "position", label: String(localized: "Primary position"), icon: "figure.run"))
    }
    if !hasHomeLocation {
      missing.append(MissingField(id: "location", label: String(localized: "Home location"), icon: "location"))
    }
    if satScore == nil && actScore == nil {
      missing.append(MissingField(id: "testScores", label: String(localized: "Test scores (SAT/ACT)"), icon: "doc.text"))
    }
    if !filled(phone) {
      missing.append(MissingField(id: "phone", label: String(localized: "Phone number"), icon: "phone"))
    }
    if heightInches == nil {
      missing.append(MissingField(id: "height", label: String(localized: "Height"), icon: "ruler"))
    }
    if weightLbs == nil {
      missing.append(MissingField(id: "weight", label: String(localized: "Weight"), icon: "scalemass"))
    }

    return Array(missing.prefix(limit))
  }
}

#Preview("Expanded") {
  ProfileCompletenessCard(
    percentage: 0.45,
    missingFields: [
      MissingField(id: "gpa", label: "GPA", icon: "graduationcap"),
      MissingField(id: "video", label: "Highlight video", icon: "play.rectangle"),
      MissingField(id: "sport", label: "Primary sport", icon: "sportscourt")
    ]
  )
  .padding()
}

#Preview("Compact") {
  ProfileCompletenessCard(
    percentage: 0.85,
    missingFields: []
  )
  .padding()
}
