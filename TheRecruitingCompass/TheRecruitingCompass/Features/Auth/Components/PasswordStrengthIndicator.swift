import SwiftUI

struct PasswordStrengthIndicator: View {
  let password: String

  private var strengthResult: (isValid: Bool, errors: [String]) {
    FormValidator.validatePasswordStrength(password)
  }

  private var strengthPercentage: Double {
    guard !password.isEmpty else { return 0 }
    let requirements = [
      password.count >= 8,
      password.contains(where: { $0.isUppercase }),
      password.contains(where: { $0.isLowercase }),
      password.contains(where: { $0.isNumber })
    ]
    return Double(requirements.filter { $0 }.count) / Double(requirements.count)
  }

  private var strengthColor: Color {
    if password.isEmpty {
      return Color.borderGray
    } else if strengthPercentage < 0.5 {
      return Color.errorRed
    } else if strengthPercentage < 1.0 {
      return Color.strengthOrange
    } else {
      return Color.primaryGreen
    }
  }

  private var strengthText: String {
    if password.isEmpty {
      return "No password"
    } else if strengthPercentage < 0.5 {
      return "Weak"
    } else if strengthPercentage < 1.0 {
      return "Fair"
    } else {
      return "Strong"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Strength")
          .font(.caption)
          .foregroundStyle(Color.secondaryText)
          .accessibilityHidden(true)

        Spacer()

        Text(strengthText)
          .font(.caption.weight(.semibold))
          .foregroundStyle(strengthColor)
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Password strength: \(strengthText)")

      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 4)
          .foregroundStyle(Color.borderGray)
          .frame(height: 6)

        RoundedRectangle(cornerRadius: 4)
          .foregroundStyle(strengthColor)
          .frame(height: 6)
          .scaleEffect(x: strengthPercentage, anchor: .leading)
          .animation(.easeInOut(duration: 0.2), value: strengthPercentage)
      }
      .frame(height: 6)
      .accessibilityHidden(true)

      if !strengthResult.errors.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(strengthResult.errors, id: \.self) { error in
            HStack(spacing: 6) {
              Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .accessibilityHidden(true)

              Text("Missing \(error)")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
            }
          }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Password requirements: \(strengthResult.errors.joined(separator: ", "))")
      }
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    VStack(alignment: .leading) {
      Text("No password")
        .font(.caption.weight(.semibold))
      PasswordStrengthIndicator(password: "")
    }

    VStack(alignment: .leading) {
      Text("Weak password")
        .font(.caption.weight(.semibold))
      PasswordStrengthIndicator(password: "weak")
    }

    VStack(alignment: .leading) {
      Text("Fair password")
        .font(.caption.weight(.semibold))
      PasswordStrengthIndicator(password: "Password12")
    }

    VStack(alignment: .leading) {
      Text("Strong password")
        .font(.caption.weight(.semibold))
      PasswordStrengthIndicator(password: "StrongPass123")
    }

    Spacer()
  }
  .padding()
}
