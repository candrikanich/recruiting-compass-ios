import SwiftUI

/// Dashboard-style card showing common parent worries for the current Timeline phase,
/// rendered as expandable accordions. Ported for parity with the web "Common Worries" widget.
struct CommonWorriesWidget: View {
  let phase: TimelinePhase

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
          DisclosureGroup {
            Text(worry.answer)
              .font(.body)
          } label: {
            Text(worry.question)
              .font(.subheadline.weight(.medium))
          }
          .padding(12)
          .background(Color.Surface.muted)
          .clipShape(.rect(cornerRadius: 8))
        }
      }
    }
  }
}
