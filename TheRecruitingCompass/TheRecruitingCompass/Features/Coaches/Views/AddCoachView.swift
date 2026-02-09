import SwiftUI

struct AddCoachView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          Image(systemName: "person.fill.badge.plus")
            .font(.system(size: 80))
            .foregroundStyle(Color.accentBlue.gradient)
            .padding(.top, 40)
            .accessibilityHidden(true)

          Text("Add Coach")
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)

          Text("This feature is coming soon. You'll be able to add new coaches to your tracked schools.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
      }
      .navigationTitle("Add Coach")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .accessibilityLabel("Cancel adding coach")
          .accessibilityHint("Dismisses the add coach screen")
        }
      }
    }
  }
}

#Preview {
  AddCoachView()
}
