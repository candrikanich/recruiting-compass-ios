import SwiftUI

struct HomeLocationView: View {
  @State private var viewModel: HomeLocationViewModel

  init(preferenceService: PreferenceManaging) {
    _viewModel = State(initialValue: HomeLocationViewModel(preferenceService: preferenceService))
  }

  var body: some View {
    Form {
      // Address Section
      Section {
        TextField("Street Address", text: Binding(
          get: { viewModel.location.address ?? "" },
          set: { viewModel.updateAddress($0) }
        ))
        .textContentType(.streetAddressLine1)
        .autocapitalization(.words)
        .accessibilityLabel("Street address")

        HStack(spacing: 12) {
          TextField("City", text: Binding(
            get: { viewModel.location.city ?? "" },
            set: { viewModel.updateCity($0) }
          ))
          .textContentType(.addressCity)
          .autocapitalization(.words)
          .accessibilityLabel("City")

          TextField("State", text: Binding(
            get: { viewModel.location.state ?? "" },
            set: { viewModel.updateState($0) }
          ))
          .textContentType(.addressState)
          .autocapitalization(.allCharacters)
          .frame(width: 60)
          .accessibilityLabel("State (2 letters)")
          .accessibilityHint("Enter 2-letter state code")
        }

        TextField("ZIP Code", text: Binding(
          get: { viewModel.location.zip ?? "" },
          set: { viewModel.updateZip($0) }
        ))
        .textContentType(.postalCode)
        .keyboardType(.numberPad)
        .accessibilityLabel("ZIP code")
        .accessibilityHint("Auto-saves when changed")
      } header: {
        Text("Address")
      } footer: {
        Text("Your home location is used to calculate distances to schools. Changes to ZIP code auto-save after 500ms.")
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
              .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
              Text("Coordinates Ready")
                .font(.subheadline)
                .fontWeight(.medium)
              Text(viewModel.coordinatesText)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Coordinates ready: \(viewModel.coordinatesText)")
        }

        if let latitude = viewModel.location.latitude, let longitude = viewModel.location.longitude {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Latitude:")
                .foregroundColor(.secondary)
              Spacer()
              Text(String(format: "%.6f", latitude))
                .fontWeight(.medium)
            }

            HStack {
              Text("Longitude:")
                .foregroundColor(.secondary)
              Spacer()
              Text(String(format: "%.6f", longitude))
                .fontWeight(.medium)
            }
          }
          .font(.subheadline)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Latitude \(String(format: "%.6f", latitude)), Longitude \(String(format: "%.6f", longitude))")
        }
      } header: {
        Text("Coordinates")
      } footer: {
        Text("Coordinates are automatically calculated from your address for distance calculations.")
          .font(.caption)
      }
    }
    .navigationTitle("Home Location")
    .preferenceSaveToolbar(
      hasUnsavedChanges: viewModel.hasUnsavedChanges,
      isSaving: viewModel.isSaving
    ) {
      await viewModel.saveLocation()
    }
    .overlay {
      PreferenceLoadingOverlay(
        isLoading: viewModel.isLoading,
        message: "Loading location..."
      )
    }
    .preferenceErrorAlert(errorMessage: $viewModel.errorMessage)
    .overlay(alignment: .top) {
      PreferenceSuccessToast(message: viewModel.successMessage)
    }
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
