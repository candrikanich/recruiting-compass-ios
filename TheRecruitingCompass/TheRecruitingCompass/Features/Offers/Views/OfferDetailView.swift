import SwiftUI

struct OfferDetailView: View {
  let offerId: String

  @State private var viewModel: OfferDetailViewModel
  @Environment(\.dismiss) private var dismiss

  init(offerId: String) {
    self.offerId = offerId
    _viewModel = State(initialValue: OfferDetailViewModel(offerId: offerId))
  }

  var body: some View {
    ScrollView {
      if viewModel.isLoading && viewModel.offer == nil {
        LoadingStateView(message: "Loading offer...")
          .padding(.top, 100)
      } else if viewModel.offer == nil, let error = viewModel.errorMessage {
        InlineErrorView(
          message: error,
          onRetry: { Task { await viewModel.loadOffer() } }
        )
        .padding(.top, 100)
      } else if viewModel.offer == nil {
        notFoundView
      } else {
        offerContent
      }
    }
    .navigationTitle("Offer Details")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .tabBar)
    .refreshable {
      await viewModel.loadOffer()
    }
    .task {
      await viewModel.loadOffer()
    }
    .alert(
      viewModel.activeAlert?.title ?? "",
      isPresented: $viewModel.isShowingActiveAlert,
      presenting: viewModel.activeAlert
    ) { alert in
      switch alert {
      case .deleteConfirmation:
        Button("Delete", role: .destructive) {
          Task {
            if await viewModel.deleteOffer() {
              dismiss()
            }
          }
        }
        Button("Cancel", role: .cancel) {}
      case .error, .deleteError:
        Button("OK", role: .cancel) {}
      }
    } message: { alert in
      switch alert {
      case .error(let message):
        Text(message)
      case .deleteConfirmation:
        Text("This will permanently delete this offer. This action cannot be undone.")
      case .deleteError(let message):
        Text(message)
      }
    }
  }

  // MARK: - Not Found

  @ViewBuilder
  private var notFoundView: some View {
    VStack(spacing: 16) {
      Image(systemName: "doc.questionmark")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)

      Text("Offer not found")
        .font(.headline)
        .foregroundStyle(.secondary)

      Button("Return to Offers") {
        dismiss()
      }
      .buttonStyle(.bordered)
    }
    .padding(.top, 100)
  }

  // MARK: - Offer Content

  @ViewBuilder
  private var offerContent: some View {
    if let offer = viewModel.offer {
      VStack(spacing: 20) {
        OfferHeaderView(
          status: offer.status,
          schoolName: viewModel.schoolName,
          offerType: offer.offerType
        )

        OfferFinancialSummary(
          formattedAmount: offer.formattedAmount,
          formattedPercentage: offer.formattedPercentage,
          deadlineText: viewModel.deadlineDisplayText,
          deadlineUrgency: offer.deadlineUrgency,
          formattedDeadlineDate: viewModel.formattedDeadlineDate
        )

        if !viewModel.isEditing {
          OfferDetailsGrid(
            offerDate: viewModel.formattedOfferDate,
            deadlineDate: viewModel.formattedDeadlineDate,
            conditions: offer.conditions,
            notes: offer.notes
          )
        }

        ScholarshipCalculatorView(
          initialAmount: offer.scholarshipAmount,
          initialPercentage: offer.scholarshipPercentage,
          onSaveToOffer: { amount, pct in
            viewModel.applyCalculatorValues(amount: amount, percentage: pct)
          }
        )

        if viewModel.isEditing {
          OfferEditForm(
            editData: $viewModel.editData,
            isUpdating: viewModel.isUpdating,
            onSave: { await viewModel.saveChanges() },
            onCancel: { viewModel.cancelEditing() }
          )
        }

        actionButtons
      }
      .padding(.bottom, 24)
    }
  }

  // MARK: - Action Buttons

  @ViewBuilder
  private var actionButtons: some View {
    Group {
      if !viewModel.isEditing {
        HStack(spacing: 12) {
          Button {
            viewModel.startEditing()
          } label: {
            Label("Edit", systemImage: "pencil")
              .frame(maxWidth: .infinity, minHeight: 44)
              .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("offer-edit-button")
          .accessibilityLabel(String(localized: "Edit offer"))
          .accessibilityHint("Opens edit form for this offer")

          Button(role: .destructive) {
            viewModel.confirmDelete()
          } label: {
            Label("Delete", systemImage: "trash")
              .frame(maxWidth: .infinity, minHeight: 44)
              .padding(.vertical, 8)
          }
          .buttonStyle(.bordered)
          .tint(.red)
          .accessibilityIdentifier("offer-delete-button")
          .accessibilityLabel(String(localized: "Delete offer"))
          .accessibilityHint("Permanently removes this offer")
        }
        .padding(.horizontal)
      }
    }
  }

}

#Preview {
  NavigationStack {
    OfferDetailView(offerId: "preview-offer-1")
  }
}
