import SwiftUI

struct SentimentBadge: View {
  let sentiment: Sentiment

  var body: some View {
    Text(sentiment.displayName)
      .font(.caption)
      .fontWeight(.medium)
      .foregroundStyle(sentiment.badgeColor.foregroundColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(sentiment.badgeColor.backgroundColor)
      .clipShape(.rect(cornerRadius: 6))
  }
}
