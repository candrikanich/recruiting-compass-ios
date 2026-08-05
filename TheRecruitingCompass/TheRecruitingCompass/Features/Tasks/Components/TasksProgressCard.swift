import SwiftUI

struct TasksProgressCard: View {
  let completed: Int
  let total: Int
  let percentage: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("You've completed \(completed) of \(total) tasks (\(percentage)%)")
        .font(.subheadline)
        .foregroundStyle(.primary)

      GeometryReader { geo in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.2))
            .frame(height: 12)

          RoundedRectangle(cornerRadius: 6)
            .fill(Color.accentBlue)
            .frame(width: total > 0 ? geo.size.width * CGFloat(completed) / CGFloat(total) : 0, height: 12)
        }
      }
      .frame(height: 12)
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(String(localized: "Completed \(completed) of \(total) tasks, \(percentage) percent complete"))
  }
}

#Preview {
  TasksProgressCard(completed: 3, total: 10, percentage: 30)
    .padding()
}
