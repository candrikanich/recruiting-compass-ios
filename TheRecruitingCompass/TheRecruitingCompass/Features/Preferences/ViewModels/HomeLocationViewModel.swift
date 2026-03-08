import CoreLocation
import Foundation
import Observation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.chrisandrikanich.TheRecruitingCompass", category: "HomeLocationViewModel")

@Observable
@MainActor
final class HomeLocationViewModel {
  var location: HomeLocation = .default
  var isLoading = false
  var errorMessage: String?
  var saveStatus: SaveStatus = .idle

  private let preferenceService: any PreferenceManaging
  private let geocoder: CLGeocoder
  @ObservationIgnored nonisolated(unsafe) private var pendingAutoSave: Task<Void, Never>?
  @ObservationIgnored nonisolated(unsafe) private var pendingStatusReset: Task<Void, Never>?

  init(preferenceService: any PreferenceManaging, geocoder: CLGeocoder = CLGeocoder()) {
    self.preferenceService = preferenceService
    self.geocoder = geocoder
  }

  nonisolated deinit {
    pendingAutoSave?.cancel()
    pendingStatusReset?.cancel()
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
      errorMessage = "Failed to load location settings. Please try again."
      isLoading = false
    }
  }

  func saveLocation() async {
    logger.debug("Saving home location")
    saveStatus = .saving
    errorMessage = nil

    do {
      _ = try await preferenceService.savePreferences(category: .location, data: location)
      saveStatus = .saved
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      logger.info("Home location saved")
      pendingStatusReset?.cancel()
      pendingStatusReset = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        if self.saveStatus == .saved { self.saveStatus = .idle }
      }
    } catch {
      logger.error("Failed to save location: \(error.localizedDescription)")
      errorMessage = "Failed to save location. Please try again."
      saveStatus = .idle
    }
  }

  // MARK: - Auto-Save

  func scheduleAutoSave() {
    pendingAutoSave?.cancel()
    saveStatus = .saving
    pendingAutoSave = Task {
      try? await Task.sleep(for: .milliseconds(1000))
      guard !Task.isCancelled else { return }
      Task { await self.saveLocation() }
    }
  }

  private func markChanged() {
    scheduleAutoSave()
  }

  // MARK: - Geocoding

  var isGeocoding = false

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
      scheduleAutoSave()
      logger.info("Geocoding successful: \(coordinate.latitude), \(coordinate.longitude)")

      isGeocoding = false
    } catch {
      logger.error("Geocoding failed: \(error.localizedDescription)")
      errorMessage = "Unable to find that location. Please enter a more specific address."
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
    let uppercased = value.uppercased()
    let limited = String(uppercased.prefix(2))
    location.state = limited.isEmpty ? nil : limited
    markChanged()
  }

  func updateZip(_ value: String) {
    let limited = String(value.prefix(10))
    location.zip = limited.isEmpty ? nil : limited
    markChanged()
  }

  // MARK: - Flat Binding Properties

  var address: String {
    get { location.address ?? "" }
    set { updateAddress(newValue) }
  }

  var city: String {
    get { location.city ?? "" }
    set { updateCity(newValue) }
  }

  var state: String {
    get { location.state ?? "" }
    set { updateState(newValue) }
  }

  var zip: String {
    get { location.zip ?? "" }
    set { updateZip(newValue) }
  }

  // MARK: - Computed

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
