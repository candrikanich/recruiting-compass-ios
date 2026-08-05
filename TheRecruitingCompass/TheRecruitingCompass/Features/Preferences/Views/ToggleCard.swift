import SwiftUI

struct ToggleCard: View {
  let icon: String
  let label: String
  @Binding var isOn: Bool
  let onChange: () -> Void
  var isComingSoon: Bool = false

  var body: some View {
    Button {
      guard !isComingSoon else { return }
      isOn.toggle()
      onChange()
    } label: {
      VStack(spacing: 8) {
        Image(systemName: icon)
          .font(.title2)
          .foregroundStyle(isComingSoon ? Color.gray.opacity(0.4) : (isOn ? Color.blue : Color.gray))

        Text(label)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundStyle(isComingSoon ? Color.secondary.opacity(0.5) : Color.primary)
          .multilineTextAlignment(.center)
          .lineLimit(2)

        if isComingSoon {
          Text("Coming Soon")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .clipShape(.rect(cornerRadius: 4))
        } else if isOn {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.green)
        } else {
          Image(systemName: "circle")
            .font(.caption)
            .foregroundStyle(.gray)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(isComingSoon ? Color(.systemGray6).opacity(0.5) : (isOn ? Color.blue.opacity(0.1) : Color(.systemGray6)))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(isOn && !isComingSoon ? Color.blue : Color.clear, lineWidth: 3)
      )
      .scaleEffect(isOn && !isComingSoon ? 1.0 : 0.98)
    }
    .buttonStyle(.plain)
    .disabled(isComingSoon)
    .accessibilityLabel(isComingSoon ? "\(label) coming soon" : "\(label) \(isOn ? "enabled" : "disabled")")
    .accessibilityHint(isComingSoon ? "Not yet available" : "Tap to toggle")
    .accessibilityAddTraits(isOn && !isComingSoon ? .isSelected : [])
  }
}
