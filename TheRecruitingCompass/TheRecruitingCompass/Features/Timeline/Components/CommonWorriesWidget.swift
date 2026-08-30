import SwiftUI

/// Dashboard-style card showing common parent worries for the current Timeline phase,
/// rendered as expandable accordions. Ported for parity with the web "Common Worries" widget.
///
/// Uses manual expand/collapse instead of DisclosureGroup to avoid SwiftUI crash
/// when DisclosureGroup animates inside LazyVStack + ScrollView.
struct CommonWorriesWidget: View {
  let phase: TimelinePhase

  @State private var expandedIDs: Set<String> = []

  var body: some View {
    let worries = ParentWorry.forPhase(phase)
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "Questions other parents ask at this stage"))
        .font(.subheadline)
        .foregroundStyle(Color.secondaryText)

      if worries.isEmpty {
        Text(String(localized: "No common worries at this stage."))
          .font(.subheadline)
          .foregroundStyle(Color.secondaryText)
      } else {
        ForEach(worries) { worry in
          WorryCard(
            worry: worry,
            isExpanded: expandedIDs.contains(worry.id),
            onToggle: {
              withAnimation(.easeInOut(duration: 0.2)) {
                if expandedIDs.contains(worry.id) {
                  expandedIDs.remove(worry.id)
                } else {
                  expandedIDs.insert(worry.id)
                }
              }
            }
          )
        }
      }
    }
  }
}

private struct WorryCard: View {
  let worry: ParentWorry
  let isExpanded: Bool
  let onToggle: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button(action: onToggle) {
        HStack {
          Text(worry.question)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

          Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.secondaryText)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        Text(worry.answer)
          .font(.body)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(12)
    .background(Color.Surface.muted)
    .clipShape(.rect(cornerRadius: 8))
  }
}
