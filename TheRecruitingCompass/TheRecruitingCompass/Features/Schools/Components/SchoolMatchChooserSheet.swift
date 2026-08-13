import SwiftUI

struct SchoolMatchChooserSheet: View {
  let matches: [ScorecardMatch]
  let onSelect: (ScorecardMatch) -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      List(matches) { match in
        Button { onSelect(match) } label: {
          VStack(alignment: .leading, spacing: 2) {
            Text(match.name).font(.body).foregroundStyle(.primary)
            if let sub = subtitle(for: match) {
              Text(sub).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("Select the Correct School")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }
      }
    }
  }

  private func subtitle(for match: ScorecardMatch) -> String? {
    [match.city, match.state].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
  }
}

private extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}

#Preview {
  SchoolMatchChooserSheet(
    matches: [ScorecardMatch(scorecardId: 1, name: "State University", city: "Davis",
      state: "CA", studentSize: 30000, admissionRate: 0.42)],
    onSelect: { _ in }, onCancel: {})
}
