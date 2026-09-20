import SwiftUI

/// Wires keyboard "next/done" focus chaining when the caller opts in via `focusedField`/`fieldID`.
/// Leaves the field's default keyboard return-key behavior untouched when the caller hasn't
/// opted into chaining, so unwired callers don't advertise a "Next" they can't act on.
struct FocusableFieldModifier: ViewModifier {
  let focusedField: FocusState<String?>.Binding?
  let fieldID: String?
  let submitLabel: SubmitLabel

  func body(content: Content) -> some View {
    if let focusedField, let fieldID {
      content
        .submitLabel(submitLabel)
        .focused(focusedField, equals: fieldID)
    } else {
      content
    }
  }
}
