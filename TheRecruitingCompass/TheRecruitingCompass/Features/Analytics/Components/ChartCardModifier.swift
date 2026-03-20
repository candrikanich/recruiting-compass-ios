import SwiftUI

struct ChartCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .padding()
      .background(Color.Surface.card)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .brandShadowSm(cornerRadius: 12)
  }
}

extension View {
  func chartCard() -> some View {
    modifier(ChartCardModifier())
  }
}
