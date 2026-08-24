import SwiftUI

/// Dashboard launcher card for the recruiting packet. Mirrors the web widget: a title with two
/// actions — Generate Packet (builds a shareable PDF of the athlete's profile, schools by tier, and
/// activity summary) and Share with a coach (navigates to the Coaches tab). Not role-gated.
struct RecruitingPacketWidget: View {
  let athlete: RecruitingPacketAthlete
  let schools: [School]
  let onShareWithCoach: () -> Void

  @State private var viewModel = RecruitingPacketViewModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 8) {
        Image(systemName: "doc.text.fill")
          .foregroundStyle(Color.Brand.blue600)
          .accessibilityHidden(true)
        Text("Recruiting Packet")
          .font(.headline)
          .accessibilityAddTraits(.isHeader)
        Spacer()
      }

      Text("A coach-ready summary of your profile, schools, and recruiting activity.")
        .font(.subheadline)
        .foregroundStyle(Color.Text.muted)
        .fixedSize(horizontal: false, vertical: true)

      if let error = viewModel.errorMessage {
        Text(error)
          .font(.caption)
          .foregroundStyle(Color.errorRed)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(Color.errorRed.opacity(0.1))
          .clipShape(.rect(cornerRadius: 8))
          .accessibilityAddTraits(.updatesFrequently)
      }

      Button {
        Task { await viewModel.generate(athlete: athlete, schools: schools) }
      } label: {
        HStack(spacing: 8) {
          if viewModel.isGenerating {
            ProgressView()
              .controlSize(.small)
              .tint(.white)
          } else {
            Image(systemName: "square.and.arrow.up")
              .accessibilityHidden(true)
          }
          Text(viewModel.isGenerating
            ? String(localized: "Generating...")
            : String(localized: "Generate Packet"))
            .font(.callout.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .foregroundStyle(.white)
        .background(viewModel.isGenerating ? Color.Brand.slate500 : Color.Brand.blue600)
        .clipShape(.rect(cornerRadius: 8))
      }
      .disabled(viewModel.isGenerating)
      .accessibilityLabel(viewModel.isGenerating
        ? String(localized: "Generating recruiting packet")
        : String(localized: "Generate recruiting packet"))
      .accessibilityHint("Creates a PDF you can share")

      Button(action: onShareWithCoach) {
        HStack(spacing: 8) {
          Image(systemName: "envelope")
            .accessibilityHidden(true)
          Text("Share with a coach")
            .font(.callout.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .foregroundStyle(Color.Brand.blue600)
        .background(Color.Brand.blue600.opacity(0.1))
        .clipShape(.rect(cornerRadius: 8))
      }
      .accessibilityLabel(String(localized: "Share with a coach"))
      .accessibilityHint("Opens your coaches list")
    }
    .padding()
    .background(Color.Surface.card)
    .clipShape(.rect(cornerRadius: 12))
    .brandShadowSm()
    .sheet(item: $viewModel.generatedPacket) { packet in
      PacketShareSheet(packet: packet)
    }
  }
}

/// Writes the generated PDF to a temp file and hands it to the system share sheet.
private struct PacketShareSheet: View {
  let packet: GeneratedPacket

  var body: some View {
    if let url = writeTempFile() {
      ActivityShareSheet(activityItems: [url])
    } else {
      ContentUnavailableView(
        String(localized: "Export Failed"),
        systemImage: "exclamationmark.triangle",
        description: Text("Unable to prepare the packet for sharing.")
      )
    }
  }

  private func writeTempFile() -> URL? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(packet.filename)
    do {
      try packet.data.write(to: url)
      return url
    } catch {
      return nil
    }
  }
}
