//
//  AdaptiveHStackVStack.swift
//  TheRecruitingCompass
//
//  Responsive layout that displays children in HStack on wide screens, VStack on narrow screens
//

import SwiftUI

/// Displays content in HStack on iPad/wide screens, VStack on iPhone/narrow screens
struct AdaptiveHStackVStack<Content: View>: View {
  let spacing: CGFloat
  @ViewBuilder let content: Content

  init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }

  var body: some View {
    ViewThatFits {
      HStack(spacing: spacing) {
        content
      }

      VStack(spacing: spacing) {
        content
      }
    }
  }
}

#Preview("Two Fields") {
  Form {
    AdaptiveHStackVStack {
      TextField("First Name", text: .constant(""))
        .textFieldStyle(.roundedBorder)

      TextField("Last Name", text: .constant(""))
        .textFieldStyle(.roundedBorder)
    }
  }
}
