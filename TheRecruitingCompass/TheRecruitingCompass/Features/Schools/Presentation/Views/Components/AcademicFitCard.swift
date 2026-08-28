import SwiftUI

struct AcademicFitCard: View {
  let analysis: AcademicFitAnalysis
  let isEnriching: Bool
  let enrichError: String?
  let onLookup: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text("Academic Fit").font(.headline)
        Text("Test score comparison").font(.caption).foregroundStyle(.secondary)
      }

      if analysis.hasSchoolData {
        ForEach(analysis.orderedSignals, id: \.label) { signal in
          AcademicFitSignalRow(signal: signal)
        }
        if let rate = analysis.admissionRate {
          Text("Acceptance rate: \(Int((rate * 100).rounded()))%")
            .font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text("No academic data for this school yet.")
          .font(.subheadline).foregroundStyle(.secondary)
        Button(action: onLookup) {
          if isEnriching {
            ProgressView()
          } else {
            Text("Look up this school's academic profile")
          }
        }
        .disabled(isEnriching)
        .accessibilityLabel(String(localized: "Look up this school's academic profile"))
        if let enrichError {
          Text(enrichError).font(.caption).foregroundStyle(.red)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.systemGray6))
    .clipShape(.rect(cornerRadius: 12))
  }
}

private struct AcademicFitSignalRow: View {
  let signal: AcademicFitSignal
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(signal.label).font(.subheadline).fontWeight(.medium)
        Spacer()
        BadgeView(text: signal.strength.label, color: signal.strength.badgeColor)
      }
      Text(signal.explanation).font(.caption).foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}

#Preview("Has data") {
  AcademicFitCard(
    analysis: AcademicFitAnalysis(
      sat: AcademicFitSignal(label: "SAT", value: nil, strength: .above,
        explanation: "1400 is above their 75th percentile (1120–1330)."),
      act: AcademicFitSignal(label: "ACT", value: nil, strength: .inRange,
        explanation: "28 falls within their typical range (24–30)."),
      hasSchoolData: true, admissionRate: 0.42),
    isEnriching: false, enrichError: nil, onLookup: {})
  .padding()
}

#Preview("Missing data") {
  AcademicFitCard(
    analysis: AcademicFitAnalysis(
      sat: AcademicFitSignal(label: "SAT", value: nil, strength: .unknown,
        explanation: "No SAT data available for this school."),
      act: AcademicFitSignal(label: "ACT", value: nil, strength: .unknown,
        explanation: "No ACT data available for this school."),
      hasSchoolData: false, admissionRate: nil),
    isEnriching: false, enrichError: nil, onLookup: {})
  .padding()
}
