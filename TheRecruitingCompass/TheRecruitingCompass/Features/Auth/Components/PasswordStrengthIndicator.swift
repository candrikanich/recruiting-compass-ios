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
      return Color(red: 0.827, green: 0.843, blue: 0.863)
    } else if strengthPercentage < 0.5 {
      return Color(red: 0.859, green: 0.149, blue: 0.149)
    } else if strengthPercentage < 1.0 {
      return Color(red: 1, green: 0.647, blue: 0)
    } else {
      return Color(red: 0.024, green: 0.588, blue: 0.412)
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
          .font(.system(size: 12, weight: .regular))
          .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))

        Spacer()

        Text(strengthText)
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(strengthColor)
      }

      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 4)
            .foregroundColor(Color(red: 0.827, green: 0.843, blue: 0.863))

          RoundedRectangle(cornerRadius: 4)
            .foregroundColor(strengthColor)
            .frame(width: geometry.size.width * strengthPercentage)
        }
      }
      .frame(height: 6)

      if !strengthResult.errors.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          ForEach(strengthResult.errors, id: \.self) { error in
            HStack(spacing: 6) {
              Image(systemName: "circle.fill")
                .font(.system(size: 4))
                .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))

              Text("Missing \(error)")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Color(red: 0.427, green: 0.467, blue: 0.514))
            }
          }
        }
      }
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    VStack(alignment: .leading) {
      Text("No password")
        .font(.system(size: 12, weight: .semibold))
      PasswordStrengthIndicator(password: "")
    }

    VStack(alignment: .leading) {
      Text("Weak password")
        .font(.system(size: 12, weight: .semibold))
      PasswordStrengthIndicator(password: "weak")
    }

    VStack(alignment: .leading) {
      Text("Fair password")
        .font(.system(size: 12, weight: .semibold))
      PasswordStrengthIndicator(password: "Password12")
    }

    VStack(alignment: .leading) {
      Text("Strong password")
        .font(.system(size: 12, weight: .semibold))
      PasswordStrengthIndicator(password: "StrongPass123")
    }

    Spacer()
  }
  .padding()
}
