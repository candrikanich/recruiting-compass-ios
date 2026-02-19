import SwiftUI

struct SchoolCoachingPhilosophySection: View {
  let philosophy: EditableCoachingPhilosophy
  let onEdit: () -> Void

  @State private var isExpanded = false

  private var hasAnyPhilosophy: Bool {
    !philosophy.coachingPhilosophy.isEmpty ||
    !philosophy.coachingStyle.isEmpty ||
    !philosophy.recruitingApproach.isEmpty ||
    !philosophy.communicationStyle.isEmpty ||
    !philosophy.successMetrics.isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("Coaching Philosophy", systemImage: "quote.bubble")
          .font(.headline)
          .foregroundStyle(.primary)

        Spacer()

        Button(action: onEdit) {
          Text("Edit")
            .font(.subheadline)
            .foregroundStyle(Color.accentBlue)
        }
        .accessibilityLabel("Edit coaching philosophy")
        .accessibilityHint("Opens form to edit coaching philosophy details")
      }

      if !hasAnyPhilosophy {
        PhilosophyEmptyState()
      } else {
        VStack(spacing: 0) {
          PhilosophyRow(
            label: "Coaching Philosophy",
            value: philosophy.coachingPhilosophy,
            isExpanded: isExpanded
          )

          PhilosophyRow(
            label: "Coaching Style",
            value: philosophy.coachingStyle,
            isExpanded: isExpanded
          )

          PhilosophyRow(
            label: "Recruiting Approach",
            value: philosophy.recruitingApproach,
            isExpanded: isExpanded
          )

          PhilosophyRow(
            label: "Communication Style",
            value: philosophy.communicationStyle,
            isExpanded: isExpanded
          )

          PhilosophyRow(
            label: "Success Metrics",
            value: philosophy.successMetrics,
            isExpanded: isExpanded,
            isLast: true
          )

          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              isExpanded.toggle()
            }
          } label: {
            HStack {
              Text(isExpanded ? "Show Less" : "Show More")
                .font(.subheadline)
                .foregroundStyle(Color.accentBlue)

              Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .foregroundStyle(Color.accentBlue)
                .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(isExpanded ? "Show less philosophy details" : "Show more philosophy details")
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
  }
}

private struct PhilosophyRow: View {
  let label: String
  let value: String
  let isExpanded: Bool
  var isLast: Bool = false

  private var displayValue: String {
    value.isEmpty ? "Not set" : value
  }

  private var valueColor: Color {
    value.isEmpty ? .secondary : .primary
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)

      Text(displayValue)
        .font(.body)
        .foregroundStyle(valueColor)
        .lineLimit(isExpanded ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 8)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(label): \(displayValue)")

    if !isLast {
      Divider()
        .accessibilityHidden(true)
    }
  }
}

private struct PhilosophyEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "quote.bubble")
        .font(.largeTitle)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("No Philosophy Added")
        .font(.headline)
        .foregroundStyle(.secondary)

      Text("Add coaching philosophy to capture the program's values")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("No coaching philosophy added")
    .accessibilityHint("Use the edit button to add coaching philosophy details")
  }
}

#Preview("With Philosophy") {
  SchoolCoachingPhilosophySection(
    philosophy: EditableCoachingPhilosophy(
      coachingPhilosophy: "Player development first, winning follows",
      coachingStyle: "Positive reinforcement with high accountability",
      recruitingApproach: "Character over talent, team-first mentality",
      communicationStyle: "Open door policy, frequent check-ins",
      successMetrics: "Player growth, team culture, on-field results"
    ),
    onEdit: {}
  )
  .padding()
}

#Preview("Empty") {
  SchoolCoachingPhilosophySection(
    philosophy: EditableCoachingPhilosophy(),
    onEdit: {}
  )
  .padding()
}
