import SwiftUI

struct InboundDraftCard: View {
  let draft: InboundEmailDraft
  let isPending: Bool
  let onConfirm: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      if let subject = draft.subject, !subject.isEmpty {
        Text(subject)
          .font(.subheadline.weight(.semibold))
      }
      if let body = draft.bodyText, !body.isEmpty {
        Text(body)
          // web renders `whitespace-pre-line` — preserve line breaks, no HTML.
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(6)
      }
      actions
    }
    .padding(16)
    .background(Color(.secondarySystemGroupedBackground))
    .clipShape(.rect(cornerRadius: 12))
  }

  @ViewBuilder
  private var header: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(senderLine)
        .font(.subheadline.weight(.medium))
      Text(draft.occurredAtDate, style: .date)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var senderLine: String {
    guard let email = draft.senderEmail, !email.isEmpty else {
      return draft.displaySenderName
    }
    return "\(draft.displaySenderName) (\(email))"
  }

  @ViewBuilder
  private var actions: some View {
    HStack(spacing: 12) {
      Button {
        onDiscard()
      } label: {
        Text("Discard")
      }
      .buttonStyle(.bordered)
      .disabled(isPending)

      Spacer()

      Button {
        onConfirm()
      } label: {
        if isPending {
          ProgressView()
        } else {
          Text("Confirm")
        }
      }
      .buttonStyle(.borderedProminent)
      .disabled(isPending)
    }
    .padding(.top, 4)
  }
}
