import SwiftUI

struct OffersListView: View {
  @State private var viewModel = OffersListViewModel()

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.allOffers.isEmpty {
        LoadingStateView(message: "Loading offers...")
      } else if viewModel.allOffers.isEmpty {
        OfferEmptyState(
          isFilteredEmpty: false,
          onClearFilters: nil,
          onAddOffer: { withAnimation { viewModel.showAddForm = true } }
        )
      } else {
        offersListContent
      }
    }
    .navigationTitle("Offers")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(
      text: $viewModel.filters.schoolSearch,
      prompt: "Search by school..."
    )
    .refreshable { await viewModel.loadOffers() }
    .task { await viewModel.loadOffers() }
    .confirmationDialog(
      "Delete Offer",
      isPresented: $viewModel.showDeleteConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        Task { await viewModel.deleteOffer() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      if let offer = viewModel.offerToDelete {
        Text("Are you sure you want to delete this offer from \(viewModel.schoolName(for: offer.schoolId))? This action cannot be undone.")
      }
    }
    .alert("Error", isPresented: Binding(
      get: { viewModel.errorMessage != nil },
      set: { if !$0 { viewModel.errorMessage = nil } }
    )) {
      Button("Retry") {
        viewModel.errorMessage = nil
        Task { await viewModel.loadOffers() }
      }
      Button("Dismiss", role: .cancel) { viewModel.errorMessage = nil }
    } message: {
      if let error = viewModel.errorMessage {
        Text(error)
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .navigationBarTrailing) {
        if viewModel.canCompare {
          Button {
            viewModel.showComparison = true
          } label: {
            Image(systemName: "arrow.left.arrow.right")
              .frame(minWidth: 44, minHeight: 44)
              .contentShape(Rectangle())
          }
          .accessibilityIdentifier("compare_button")
          .accessibilityLabel("Compare \(viewModel.selectedOfferIds.count) offers")
          .accessibilityHint("Opens side-by-side comparison of selected offers")
        }

        Button {
          withAnimation { viewModel.showAddForm.toggle() }
        } label: {
          Image(systemName: "plus")
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("add_offer_button")
        .accessibilityLabel("Log new offer")
        .accessibilityHint("Opens form to log a new offer")
      }
    }
    .sheet(isPresented: $viewModel.showComparison) {
      OfferComparisonSheet(
        offers: viewModel.selectedOffers,
        schoolNameFor: { viewModel.schoolName(for: $0) }
      )
    }
    .toast(
      isShowing: $viewModel.showSuccessToast,
      message: $viewModel.successMessage,
      type: .success,
      duration: 3.0
    )
    .navigationDestination(for: OfferDestination.self) { destination in
      switch destination {
      case .detail(let offerId):
        OfferDetailView(offerId: offerId)
      }
    }
    .accessibilityIdentifier("offers_list")
  }

  // MARK: - List Content

  private var offersListContent: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        OfferSummaryCards(
          acceptedCount: viewModel.acceptedCount,
          pendingCount: viewModel.pendingCount,
          declinedCount: viewModel.declinedCount
        )
        .padding(.vertical, 8)

        if viewModel.showAddForm {
          AddOfferForm(
            formState: $viewModel.formState,
            schools: viewModel.schools,
            isSubmitting: viewModel.isSubmitting,
            onSave: { Task { await viewModel.createOffer() } },
            onCancel: {
              withAnimation {
                viewModel.formState.reset()
                viewModel.showAddForm = false
              }
            }
          )
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
        }

        OfferFilterBar(filters: $viewModel.filters)
          .padding(.vertical, 8)

        FilteredResultsHeader(
          resultCount: viewModel.filteredOffers.count,
          itemName: "offer",
          activeFilterCount: viewModel.filters.activeFilterCount
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)

        if viewModel.filteredOffers.isEmpty {
          OfferEmptyState(
            isFilteredEmpty: true,
            onClearFilters: { viewModel.clearFilters() }
          )
        } else {
          offerCards
        }
      }
    }
  }

  private var offerCards: some View {
    ForEach(viewModel.filteredOffers) { offer in
      NavigationLink(value: OfferDestination.detail(offer.id)) {
        OfferCard(
          offer: offer,
          schoolName: viewModel.schoolName(for: offer.schoolId),
          isSelected: viewModel.selectedOfferIds.contains(offer.id),
          onToggleSelection: { viewModel.toggleSelection(offer.id) },
          onDelete: { viewModel.confirmDelete(offer) }
        )
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 16)
      .padding(.vertical, 4)
    }
  }
}

#Preview {
  NavigationStack {
    OffersListView()
  }
  .environment(FamilyManager.shared)
}
