import SwiftUI

/// Colored 2×3 action grid (Email / Text / Call / Twitter / Instagram / Log
/// Activity) matching the coach-detail Figma frame. Only renders a channel when
/// the coach has that contact field; Log Activity always shows.
struct CoachDirectChannelsGrid: View {
  let coach: Coach
  var onEmail: () -> Void = {}
  var onText: () -> Void = {}
  var onCall: () -> Void = {}
  var onTwitter: () -> Void = {}
  var onInstagram: () -> Void = {}
  var onLog: () -> Void = {}

  @Environment(\.sizeCategory) private var sizeCategory
  @Environment(FeatureFlagStore.self) private var featureFlags: FeatureFlagStore?

  private var columns: [GridItem] {
    [GridItem(.flexible(), spacing: 10),
     GridItem(.flexible(), spacing: 10),
     GridItem(.flexible(), spacing: 10)]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: 10) {
      ForEach(CoachChannel.visible(for: coach, outreachEnabled: featureFlags.isEnabled(.athleteMessages)),
              id: \.self) { channel in
        channelPill(channel)
      }
      pill(label: "Log Activity", system: "plus", fill: AnyShapeStyle(Color.Brand.slate700), action: onLog)
    }
  }

  @ViewBuilder
  private func channelPill(_ channel: CoachChannel) -> some View {
    switch channel {
    case .email:
      pill(label: "Email", system: "envelope.fill", fill: AnyShapeStyle(Color.Brand.forest600), action: onEmail)
    case .text:
      pill(label: "Text", system: "message.fill", fill: AnyShapeStyle(Color.Brand.emerald700), action: onText)
    case .call:
      pill(label: "Call", system: "phone.fill", fill: AnyShapeStyle(Color.Brand.orange700), action: onCall)
    case .twitter:
      pill(label: "Twitter", asset: "LogoX", fill: AnyShapeStyle(Color.Brand.forest700), action: onTwitter)
    case .instagram:
      pill(label: "Instagram", asset: "LogoInstagram",
           fill: AnyShapeStyle(Color.Brand.gold700),
           action: onInstagram)
    }
  }

  @ViewBuilder
  private func pill(label: LocalizedStringKey, system: String? = nil, asset: String? = nil,
                    fill: AnyShapeStyle, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let asset {
          Image(asset).renderingMode(.template).resizable().scaledToFit().frame(width: 16, height: 16)
        } else if let system {
          Image(systemName: system).font(.system(size: 14, weight: .semibold))
        }
        Text(label).font(.brand(.subheadline, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 44)
      .padding(.horizontal, 8)
      .background(fill)
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .accessibilityLabel(label)
  }
}
