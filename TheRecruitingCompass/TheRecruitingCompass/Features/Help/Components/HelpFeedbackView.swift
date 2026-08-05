//
//  HelpFeedbackView.swift
//  TheRecruitingCompass
//
//  "Was this page helpful?" thumbs up/down + contact support link (matches web HelpFeedback).
//

import SwiftUI

struct HelpFeedbackView: View {
  @State private var viewModel: HelpFeedbackViewModel

  init(page: String, feedbackService: HelpFeedbackManaging = HelpFeedbackServiceImpl()) {
    self._viewModel = State(initialValue: HelpFeedbackViewModel(page: page, feedbackService: feedbackService))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if !viewModel.submitted {
        VStack(alignment: .leading, spacing: 8) {
          Text("Was this page helpful?")
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(.primary)
          Text("Your feedback helps us improve our docs.")
            .font(.caption)
            .foregroundStyle(.secondary)

          HStack(spacing: 12) {
            Button {
              Task { await viewModel.submit(helpful: true) }
            } label: {
              Label("Yes", systemImage: "hand.thumbsup")
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(HelpFeedbackButtonStyle(highlight: true))
            .disabled(viewModel.isLoading)
            .accessibilityLabel(String(localized: "Yes, this page was helpful"))
            .accessibilityHint("Submit positive feedback")

            Button {
              Task { await viewModel.submit(helpful: false) }
            } label: {
              Label("No", systemImage: "hand.thumbsdown")
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(HelpFeedbackButtonStyle(highlight: false))
            .disabled(viewModel.isLoading)
            .accessibilityLabel(String(localized: "No, this page was not helpful"))
            .accessibilityHint("Submit negative feedback")
          }

          if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
              .font(.caption)
              .foregroundStyle(Color.errorRed)
              .accessibilityLabel(errorMessage)
          }
        }
      } else {
        Label("Thanks for your feedback!", systemImage: "checkmark.circle.fill")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(Color.primaryGreen)
          .accessibilityLabel(String(localized: "Thanks for your feedback!"))
      }

      supportLink
    }
    .padding(.top, 16)
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var supportLink: some View {
    HStack(spacing: 6) {
      Image(systemName: "envelope")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("Need more help?")
        .font(.caption)
        .foregroundStyle(.secondary)
      if let url = URL(string: "mailto:support@therecruitingcompass.com") {
        Link("Contact support", destination: url)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(Color.accentBlue)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Need more help? Contact support"))
  }
}

private struct HelpFeedbackButtonStyle: ButtonStyle {
  let highlight: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(highlight ? Color.primaryGreen : Color.errorRed)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(highlight ? Color.primaryGreen.opacity(0.12) : Color.errorRed.opacity(0.12))
      )
      .overlay {
        RoundedRectangle(cornerRadius: 10)
          .stroke(highlight ? Color.primaryGreen.opacity(0.4) : Color.errorRed.opacity(0.4), lineWidth: 1)
      }
      .opacity(configuration.isPressed ? 0.8 : 1)
  }
}

#Preview {
  HelpFeedbackView(page: "/help/getting-started")
    .environment(AuthManager.shared)
}
