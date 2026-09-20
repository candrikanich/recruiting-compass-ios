import SwiftUI

/// Previous/Next chevron arrows pinned above the keyboard, chaining focus across `order`.
/// Numeric keypads (`.numberPad`, `.decimalPad`, etc.) have no return key, so
/// `.submitLabel`/`.onSubmit` chaining never fires for them — this toolbar is the only way
/// to move between those fields without dismissing the keyboard.
private struct KeyboardFieldNavigationModifier<Field: Hashable>: ViewModifier {
  let focusedField: FocusState<Field?>.Binding
  let order: [Field]

  private var currentIndex: Int? {
    focusedField.wrappedValue.flatMap { order.firstIndex(of: $0) }
  }

  func body(content: Content) -> some View {
    content.toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Button {
          if let index = currentIndex, index > 0 {
            focusedField.wrappedValue = order[index - 1]
          }
        } label: {
          Image(systemName: "chevron.up")
        }
        .disabled((currentIndex ?? 0) <= 0)
        .accessibilityLabel(String(localized: "Previous field"))

        Button {
          if let index = currentIndex, index < order.count - 1 {
            focusedField.wrappedValue = order[index + 1]
          }
        } label: {
          Image(systemName: "chevron.down")
        }
        .disabled(currentIndex.map { $0 >= order.count - 1 } ?? true)
        .accessibilityLabel(String(localized: "Next field"))

        Spacer()

        Button(String(localized: "Done")) {
          focusedField.wrappedValue = nil
        }
      }
    }
  }
}

extension View {
  /// Adds Previous/Next/Done keyboard-accessory navigation, chaining across `order` by focus id.
  /// Attach once per form, at a container that wraps every focusable field.
  func keyboardFieldNavigation<Field: Hashable>(
    focusedField: FocusState<Field?>.Binding,
    order: [Field]
  ) -> some View {
    modifier(KeyboardFieldNavigationModifier(focusedField: focusedField, order: order))
  }
}
