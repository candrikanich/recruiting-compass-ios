import SwiftUI

struct ChartCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding()
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
  }
}

extension View {
  func chartCard() -> some View {
    modifier(ChartCardModifier())
  }
}
