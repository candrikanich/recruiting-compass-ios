import SwiftUI

struct Banner: View {
  enum Style {
    case error
    case warning

    var iconName: String {
      switch self {
      case .error: "exclamationmark.circle.fill"
      case .warning: "hourglass"
      }
    }

    var foregroundColor: Color {
      switch self {
      case .error: .errorRed
      case .warning: .warningOrange
      }
    }

    var backgroundColor: Color {
      switch self {
      case .error: .errorBackground
      case .warning: .warningBackground
      }
    }

    var borderColor: Color {
      switch self {
      case .error: .errorBorder
      case .warning: .warningBorder
      }
    }
  }

  let style: Style
  let message: String
  let onDismiss: (() -> Void)?

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: style.iconName)
        .foregroundStyle(style.foregroundColor)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 2) {
        Text(message)
          .font(.footnote)
          .foregroundStyle(style.foregroundColor)
      }

      Spacer()

      if let onDismiss {
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .foregroundStyle(style.foregroundColor)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(String(localized: "Close message"))
      }
    }
    .padding(12)
    .background(style.backgroundColor)
    .border(style.borderColor, width: 1)
    .clipShape(.rect(cornerRadius: 8))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: style == .error ? "Error: \(message)" : "Warning: \(message)"))
  }
}
