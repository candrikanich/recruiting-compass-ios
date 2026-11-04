import SwiftUI

/// Lets a parent in two or more families pick which player's family the app shows (web's athlete switcher).
struct FamilySwitcher: View {
  let choices: [FamilySelection.Choice]
  let selectedFamilyId: String?
  let onSelect: (String) -> Void

  var body: some View {
    if choices.count > 1 {
      HStack {
        Text("Family")
          .font(.brand(.headline))
        Spacer()
        Picker("Family", selection: selection) {
          ForEach(choices) { choice in
            Text(choice.label).tag(choice.id)
          }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("family_switcher")
      }
      .padding()
      .frame(minHeight: 44)
      .background(Color.Surface.card)
      .clipShape(.rect(cornerRadius: 12))
      .brandShadowSm()
    }
  }

  private var selection: Binding<String> {
    Binding(
      get: { selectedFamilyId ?? choices.first?.id ?? "" },
      set: { onSelect($0) }
    )
  }
}
