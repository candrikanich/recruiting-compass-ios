import SwiftUI

struct InboundDraftCard: View {
  let draft: InboundEmailDraft
  let schools: [School]
  let isPending: Bool
  @Binding var pickedSchoolId: String?
  let canConfirm: Bool
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
      if draft.matchedSchoolId == nil {
        SchoolPicker(selectedSchoolId: $pickedSchoolId, schools: schools, isDisabled: isPending)
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
      Text(draft.displayDate, style: .date)
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
      .disabled(isPending || !canConfirm)
    }
    .padding(.top, 4)
  }
}

private extension InboundEmailDraft {
  var displayDate: Date {
    if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: occurredAt) { return date }
    if let date = ISO8601DateFormatter().date(from: occurredAt) { return date }
    return .now
  }
}

private extension ISO8601DateFormatter {
  static let withFractionalSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()
}
