import SwiftUI

struct CoreCoursesEditor: View {
    @Binding var courses: [String]
    let isDisabled: Bool
    @State private var newCourse: String = ""

    static let maxCourses = 20
    static let maxLength = 60

    /// Returns the normalized course to append, or nil if it must be rejected.
    static func normalizedToAdd(_ raw: String, existing: [String]) -> String? {
        let trimmed = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
        guard !trimmed.isEmpty else { return nil }
        guard existing.count < maxCourses else { return nil }
        guard !existing.contains(trimmed) else { return nil }
        return trimmed
    }

    private func add() {
        guard let course = Self.normalizedToAdd(newCourse, existing: courses) else { return }
        courses.append(course)
        newCourse = ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AP, honors, or notable courses for your recruiting profile.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !courses.isEmpty {
                WrapLayout(spacing: 8) {
                    ForEach(courses, id: \.self) { course in
                        HStack(spacing: 6) {
                            Text(course).font(.subheadline)
                            if !isDisabled {
                                Button {
                                    courses.removeAll { $0 == course }
                                } label: {
                                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(course)")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(Capsule())
                    }
                }
            }

            if !isDisabled && courses.count < Self.maxCourses {
                HStack(spacing: 8) {
                    TextField("e.g., AP Chemistry", text: $newCourse)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .buttonStyle(.borderedProminent)
                        .disabled(newCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else if courses.count >= Self.maxCourses {
                Text("Maximum 20 courses added.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct WrapLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0, rowHeight: CGFloat = 0, totalHeight: CGFloat = 0, maxRowWidth: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                maxRowWidth = max(maxRowWidth, rowWidth - spacing)
                rowWidth = 0; rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        maxRowWidth = max(maxRowWidth, rowWidth - spacing)
        return CGSize(width: min(maxWidth, maxRowWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
