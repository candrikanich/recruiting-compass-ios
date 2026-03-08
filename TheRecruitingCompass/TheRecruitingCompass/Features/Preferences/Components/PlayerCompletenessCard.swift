import SwiftUI

struct PlayerCompletenessCard: View {
    let score: Double  // 0.0 - 1.0

    private var percentage: Int { Int(score * 100) }

    private var progressColor: Color {
        switch score {
        case 0..<0.4: return .red
        case 0.4..<0.75: return .yellow
        default: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profile Completeness")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(percentage)%")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(progressColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.red, .yellow, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * score, height: 8)
                        .animation(.spring(response: 0.4), value: score)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile \(percentage)% complete")
    }
}

#Preview {
    VStack(spacing: 16) {
        PlayerCompletenessCard(score: 0.2)
        PlayerCompletenessCard(score: 0.6)
        PlayerCompletenessCard(score: 0.9)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
