import SwiftUI

struct EventPerformanceSection: View {
  let event: FullEvent

  var body: some View {
    Section {
      if let notes = event.performanceNotes, !notes.isEmpty {
        Text(notes)
          .accessibilityLabel("Performance notes: \(notes)")
      }
    } header: {
      Text("Performance Notes")
    }
  }
}
