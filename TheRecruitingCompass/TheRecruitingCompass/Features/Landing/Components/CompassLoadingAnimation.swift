//
//  CompassLoadingAnimation.swift
//  TheRecruitingCompass
//

import SwiftUI

/// Brand loading indicator: the compass mark swings left/right around north,
/// evoking a compass needle searching for its heading.
struct CompassLoadingAnimation: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.sizeCategory) private var sizeCategory
  @State private var rotationAngle: Double = -18

  private static let swingDuration = 1.1

  var body: some View {
    Image("AppLogo")
      .resizable()
      .scaledToFit()
      .containerRelativeFrame(.horizontal) { size, _ in size * 0.5 }
      .scaleEffect(sizeCategory >= .extraLarge ? 1.08 : 1.0)
      .rotationEffect(.degrees(reduceMotion ? 0 : rotationAngle))
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(
          .easeInOut(duration: Self.swingDuration).repeatForever(autoreverses: true)
        ) {
          rotationAngle = 18
        }
      }
      .accessibilityLabel("Loading")
      .accessibilityAddTraits(.updatesFrequently)
  }
}
