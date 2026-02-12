import Foundation
import Combine
import CoreLocation
import OSLog

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "HomeLocationViewModel")

@MainActor
final class HomeLocationViewModel: ObservableObject {
  @Published var location: HomeLocation = .default
  @Published var isLoading = false
  @Published var isSaving = false
  @Published var isGeocoding = false
  @Published var errorMessage: String?
  @Published var successMessage: String?
  @Published var hasUnsavedChanges = false

  private let preferenceService: PreferenceManaging
  private let geocoder: CLGeocoder
  private var saveTask: Task<Void, Never>?
  private var cancellables = Set<AnyCancellable>()

  init(preferenceService: PreferenceManaging, geocoder: CLGeocoder = CLGeocoder()) {
    self.preferenceService = preferenceService
    self.geocoder = geocoder
    setupAutoSave()
  }

  deinit {
    saveTask?.cancel()
    cancellables.removeAll()
  }

  // MARK: - Load/Save

  func loadLocation() async {
    logger.debug("Loading home location")
    isLoading = true
    errorMessage = nil

    do {
      if let savedLocation: HomeLocation = try await preferenceService.fetchPreferences(category: .location) {
        location = savedLocation
        logger.info("Loaded existing home location")
      } else {
        location = .default
        logger.info("No existing location, using defaults")
      }
      isLoading = false
    } catch {
      logger.error("Failed to load location: \(error.localizedDescription)")
      errorMessage = "Failed to load location: \(error.localizedDescription)"
      isLoading = false
    }
  }

  func saveLocation() async {
    logger.debug("Saving home location")
    isSaving = true
    errorMessage = nil
    successMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .location, data: location)
      hasUnsavedChanges = false
      successMessage = "Location saved successfully"
      logger.info("Home location saved")

      // Clear success message after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        await MainActor.run {
          if successMessage == "Location saved successfully" {
            successMessage = nil
          }
        }
      }

      isSaving = false
    } catch {
      logger.error("Failed to save location: \(error.localizedDescription)")
      errorMessage = "Failed to save location: \(error.localizedDescription)"
      isSaving = false
    }
  }

  // MARK: - Geocoding

  func geocodeAddress() async {
    guard hasValidAddress else {
      errorMessage = "Please enter at least a city and state"
      return
    }

    logger.debug("Geocoding address")
    isGeocoding = true
    errorMessage = nil

    do {
      let addressString = buildAddressString()
      let placemarks = try await geocoder.geocodeAddressString(addressString)

      guard let coordinate = placemarks.first?.location?.coordinate else {
        throw GeocodingError.noResults
      }

      location.latitude = coordinate.latitude
      location.longitude = coordinate.longitude
      hasUnsavedChanges = true
      logger.info("Geocoding successful: \(coordinate.latitude), \(coordinate.longitude)")

      isGeocoding = false
    } catch {
      logger.error("Geocoding failed: \(error.localizedDescription)")
      errorMessage = "Geocoding failed: \(error.localizedDescription)"
      isGeocoding = false
    }
  }

  // MARK: - Field Updates

  func updateAddress(_ value: String) {
    location.address = value.isEmpty ? nil : value
    markChanged()
  }

  func updateCity(_ value: String) {
    location.city = value.isEmpty ? nil : value
    markChanged()
  }

  func updateState(_ value: String) {
    // Auto-uppercase and limit to 2 characters
    let uppercased = value.uppercased()
    let limited = String(uppercased.prefix(2))
    location.state = limited.isEmpty ? nil : limited
    markChanged()
  }

  func updateZip(_ value: String) {
    // Limit to 10 characters (allows ZIP+4)
    let limited = String(value.prefix(10))
    location.zip = limited.isEmpty ? nil : limited
    markChanged()
    triggerAutoSave()
  }

  // MARK: - Private Helpers

  private func markChanged() {
    hasUnsavedChanges = true
  }

  private func setupAutoSave() {
    // Debounce auto-save on ZIP changes (500ms)
    $location
      .dropFirst() // Ignore initial value
      .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self, self.hasUnsavedChanges else { return }
        Task {
          await self.saveLocation()
        }
      }
      .store(in: &cancellables)
  }

  private func triggerAutoSave() {
    // Auto-save is handled by the debounced publisher
  }

  var hasValidAddress: Bool {
    let hasCity = location.city?.isEmpty == false
    let hasState = location.state?.isEmpty == false
    return hasCity && hasState
  }

  private func buildAddressString() -> String {
    var parts: [String] = []

    if let address = location.address, !address.isEmpty {
      parts.append(address)
    }
    if let city = location.city, !city.isEmpty {
      parts.append(city)
    }
    if let state = location.state, !state.isEmpty {
      parts.append(state)
    }
    if let zip = location.zip, !zip.isEmpty {
      parts.append(zip)
    }

    return parts.joined(separator: ", ")
  }

  var hasCoordinates: Bool {
    location.latitude != nil && location.longitude != nil
  }

  var coordinatesText: String {
    guard let lat = location.latitude, let lon = location.longitude else {
      return "No coordinates set"
    }
    return String(format: "%.6f, %.6f", lat, lon)
  }
}

enum GeocodingError: LocalizedError {
  case noResults

  var errorDescription: String? {
    switch self {
    case .noResults:
      return "Could not find coordinates for this address"
    }
  }
}
