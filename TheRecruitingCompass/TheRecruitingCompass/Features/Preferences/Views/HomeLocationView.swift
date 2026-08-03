import SwiftUI

struct HomeLocationView: View {
  @State private var viewModel: HomeLocationViewModel

  init(preferenceService: PreferenceManaging) {
    _viewModel = State(initialValue: HomeLocationViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    @Bindable var viewModel = viewModel
    Form {
      // Address Section
      Section {
        Button {
          Task { await viewModel.useCurrentLocation() }
        } label: {
          HStack {
            Image(systemName: "location.fill")
            Text("Use My Location")
            if viewModel.isRequestingLocation {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(viewModel.isRequestingLocation)
        .accessibilityLabel("Use current location")
        .accessibilityHint("Fills in your address using your current GPS location")

        TextField("Street Address", text: $viewModel.address)
          .textContentType(.streetAddressLine1)
          .autocapitalization(.words)
          .accessibilityLabel("Street address")

        HStack(spacing: 12) {
          TextField("City", text: $viewModel.city)
            .textContentType(.addressCity)
            .autocapitalization(.words)
            .accessibilityLabel("City")

          TextField("State", text: $viewModel.state)
            .textContentType(.addressState)
            .autocapitalization(.allCharacters)
            .frame(width: 60)
            .accessibilityLabel("State (2 letters)")
            .accessibilityHint("Enter 2-letter state code")
        }

        TextField("ZIP Code", text: $viewModel.zip)
          .textContentType(.postalCode)
          .keyboardType(.numberPad)
          .accessibilityLabel("ZIP code")
      } header: {
        Text("Address")
      } footer: {
        Text("Your home location is used to calculate distances to schools. Changes save automatically.")
          .font(.caption)
      }

      // Coordinates Section
      Section {
        Button {
          Task {
            await viewModel.geocodeAddress()
          }
        } label: {
          HStack {
            Image(systemName: "mappin.and.ellipse")
            Text("Lookup from Address")
            if viewModel.isGeocoding {
              Spacer()
              ProgressView()
            }
          }
        }
        .disabled(!viewModel.hasValidAddress || viewModel.isGeocoding)
        .accessibilityLabel("Lookup coordinates from address")
        .accessibilityHint(viewModel.hasValidAddress ? "Tap to geocode address" : "Enter city and state first")

        if viewModel.hasCoordinates {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
              Text("Coordinates Ready")
                .font(.subheadline)
                .fontWeight(.medium)
              Text(viewModel.coordinatesText)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Coordinates ready: \(viewModel.coordinatesText)")
        }

        if let latitude = viewModel.location.latitude, let longitude = viewModel.location.longitude {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Latitude:")
                .foregroundStyle(.secondary)
              Spacer()
              Text(latitude, format: .number.precision(.fractionLength(6)))
                .fontWeight(.medium)
            }

            HStack {
              Text("Longitude:")
                .foregroundStyle(.secondary)
              Spacer()
              Text(longitude, format: .number.precision(.fractionLength(6)))
                .fontWeight(.medium)
            }
          }
          .font(.subheadline)
          .accessibilityElement(children: .combine)
          .accessibilityLabel(
            "Latitude \(latitude.formatted(.number.precision(.fractionLength(6)))), " +
            "Longitude \(longitude.formatted(.number.precision(.fractionLength(6))))"
          )
        }
      } header: {
        Text("Coordinates")
      } footer: {
        Text("Coordinates are automatically calculated from your address for distance calculations.")
          .font(.caption)
      }
    }
    .navigationTitle("Home Location")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .principal) {
        SaveStatusView(status: viewModel.saveStatus)
      }
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading location..."
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .sensoryFeedback(.success, trigger: viewModel.hapticSuccessTrigger)
    .task {
      await viewModel.loadLocation()
    }
  }

}

#Preview {
  let location = HomeLocation(
    address: "123 Main St",
    city: "Springfield",
    state: "IL",
    zip: "62701",
    latitude: 39.7817,
    longitude: -89.6501
  )

  // Simple preview mock
  final class PreviewMock: PreferenceManaging {
    let location: HomeLocation
    init(location: HomeLocation) { self.location = location }
    func fetchPreferences<T: Codable>(category: PreferenceCategory) async throws -> T? {
      return location as? T
    }
    func savePreferences<T: Codable>(category: PreferenceCategory, data: T) async throws -> T { data }
    func deletePreferences(category: PreferenceCategory) async throws {}
  }

  return NavigationStack {
    HomeLocationView(preferenceService: PreviewMock(location: location))
  }
}
