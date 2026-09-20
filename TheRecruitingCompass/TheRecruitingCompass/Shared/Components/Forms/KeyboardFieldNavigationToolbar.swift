import SwiftUI

/// Adds a `.keyboard`-placement toolbar with previous/next chevrons plus a Done button,
/// stepping a `@FocusState` enum through an explicit, caller-ordered list of fields.
/// An explicit list (rather than `CaseIterable.allCases`) lets callers reflect which
/// fields are actually visible (e.g. conditionally-shown guardian email / family code).
private struct KeyboardFieldNavigationToolbar<Field: Hashable>: ViewModifier {
  var focusedField: FocusState<Field?>.Binding
  let fields: [Field]

  private var currentIndex: Int? {
    focusedField.wrappedValue.flatMap { fields.firstIndex(of: $0) }
  }

  private func step(by offset: Int) {
    guard let index = currentIndex else { return }
    let target = index + offset
    guard fields.indices.contains(target) else { return }
    focusedField.wrappedValue = fields[target]
  }

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Button(action: { step(by: -1) }) {
          Image(systemName: "chevron.up")
        }
        .disabled(currentIndex == nil || currentIndex == 0)
        .accessibilityLabel(String(localized: "Previous field"))

        Button(action: { step(by: 1) }) {
          Image(systemName: "chevron.down")
        }
        .disabled(currentIndex == nil || currentIndex == fields.count - 1)
        .accessibilityLabel(String(localized: "Next field"))

        Spacer()

        Button(String(localized: "Done")) { focusedField.wrappedValue = nil }
          .accessibilityLabel(String(localized: "Dismiss keyboard"))
      }
    }
  }
}

extension View {
  func keyboardFieldNavigation<Field: Hashable>(
    focusedField: FocusState<Field?>.Binding,
    fields: [Field]
  ) -> some View {
    modifier(KeyboardFieldNavigationToolbar(focusedField: focusedField, fields: fields))
  }
}
