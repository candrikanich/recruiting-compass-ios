import SwiftUI

struct SchoolProsConsSection: View {
  let pros: [String]
  let cons: [String]
  @Binding var newPro: String
  @Binding var newCon: String
  let onAddPro: () async -> Void
  let onRemovePro: (Int) async -> Void
  let onAddCon: () async -> Void
  let onRemoveCon: (Int) async -> Void
  let isAddingPro: Bool
  let isAddingCon: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Pros & Cons")
        .font(.headline)
        .accessibilityAddTraits(.isHeader)

      HStack(alignment: .top, spacing: 16) {
        // Pros column
        VStack(alignment: .leading, spacing: 8) {
          Text("Pros")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.green)

          ForEach(Array(pros.enumerated()), id: \.offset) { index, pro in
            ProItem(text: pro) {
              Task { await onRemovePro(index) }
            }
          }

          HStack(spacing: 8) {
            TextField("Add a pro...", text: $newPro)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                Task { await onAddPro() }
              }
              .accessibilityLabel("Add pro input")

            Button {
              Task { await onAddPro() }
            } label: {
              if isAddingPro {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "plus.circle.fill")
                  .foregroundStyle(.green)
                  .font(.title2)
              }
            }
            .frame(width: 44, height: 44)
            .disabled(newPro.trimmingCharacters(in: .whitespaces).isEmpty || isAddingPro)
            .accessibilityLabel("Add pro")
          }
        }
        .frame(maxWidth: .infinity)

        // Cons column
        VStack(alignment: .leading, spacing: 8) {
          Text("Cons")
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.red)

          ForEach(Array(cons.enumerated()), id: \.offset) { index, con in
            ConItem(text: con) {
              Task { await onRemoveCon(index) }
            }
          }

          HStack(spacing: 8) {
            TextField("Add a con...", text: $newCon)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                Task { await onAddCon() }
              }
              .accessibilityLabel("Add con input")

            Button {
              Task { await onAddCon() }
            } label: {
              if isAddingCon {
                ProgressView()
                  .progressViewStyle(.circular)
                  .scaleEffect(0.8)
              } else {
                Image(systemName: "plus.circle.fill")
                  .foregroundStyle(.red)
                  .font(.title2)
              }
            }
            .frame(width: 44, height: 44)
            .disabled(newCon.trimmingCharacters(in: .whitespaces).isEmpty || isAddingCon)
            .accessibilityLabel("Add con")
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

struct ProItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
        .font(.caption)
        .accessibilityHidden(true)

      Text(text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .frame(width: 30, height: 30)
      .accessibilityLabel("Remove \(text)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.green.opacity(0.1))
    .cornerRadius(8)
  }
}

struct ConItem: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "xmark.circle.fill")
        .foregroundStyle(.red)
        .font(.caption)
        .accessibilityHidden(true)

      Text(text)
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)

      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
          .font(.caption)
      }
      .frame(width: 30, height: 30)
      .accessibilityLabel("Remove \(text)")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.red.opacity(0.1))
    .cornerRadius(8)
  }
}

#Preview {
  ScrollView {
    SchoolProsConsSection(
      pros: [
        "Excellent academic reputation",
        "Strong baseball program",
        "Beautiful campus"
      ],
      cons: [
        "Far from home",
        "Expensive tuition",
        "Cold weather"
      ],
      newPro: .constant(""),
      newCon: .constant(""),
      onAddPro: {},
      onRemovePro: { _ in },
      onAddCon: {},
      onRemoveCon: { _ in },
      isAddingPro: false,
      isAddingCon: false
    )
    .padding()
  }
}
