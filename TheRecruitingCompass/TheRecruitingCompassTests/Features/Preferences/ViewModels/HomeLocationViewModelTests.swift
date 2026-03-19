import XCTest
import CoreLocation
@testable import TheRecruitingCompass

@MainActor
final class HomeLocationViewModelTests: XCTestCase {
  nonisolated deinit {}
  var viewModel: HomeLocationViewModel!
  var mockService: MockPreferenceManager!
  var mockGeocoder: MockGeocoder!

  override func setUp() async throws {
    try await super.setUp()
    mockService = MockPreferenceManager()
    mockGeocoder = MockGeocoder()
    viewModel = HomeLocationViewModel(preferenceService: mockService, geocoder: mockGeocoder)
  }

  override func tearDown() {
    viewModel = nil
    mockService = nil
    mockGeocoder = nil
    super.tearDown()
  }

  // MARK: - Load Tests

  func testLoadLocation_WhenLocationExists_LoadsData() async {
    // Given
    let expectedLocation = HomeLocation(
      address: "123 Main St",
      city: "Springfield",
      state: "IL",
      zip: "62701",
      latitude: 39.7817,
      longitude: -89.6501
    )
    mockService.fetchPreferencesResult = .success(expectedLocation)

    // When
    await viewModel.loadLocation()

    // Then
    XCTAssertEqual(viewModel.location, expectedLocation)
    XCTAssertFalse(viewModel.isLoading)
    XCTAssertNil(viewModel.errorMessage)
  }

  func testLoadLocation_WhenNoLocation_UsesDefaults() async {
    // Given
    mockService.fetchPreferencesResult = .success(nil)

    // When
    await viewModel.loadLocation()

    // Then
    XCTAssertEqual(viewModel.location, HomeLocation.default)
    XCTAssertFalse(viewModel.isLoading)
  }

  func testLoadLocation_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.fetchPreferencesResult = .failure(PreferenceError.fetchFailed("Network error"))

    // When
    await viewModel.loadLocation()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isLoading)
  }

  // MARK: - Save Tests

  func testSaveLocation_SavesSuccessfully() async {
    // Given
    mockService.savePreferencesResult = .success(viewModel.location)

    // When
    await viewModel.saveLocation()

    // Then
    XCTAssertEqual(viewModel.saveStatus, .saved)
  }

  func testSaveLocation_WhenErrorOccurs_SetsErrorMessage() async {
    // Given
    mockService.savePreferencesResult = .failure(PreferenceError.saveFailed("Network error"))

    // When
    await viewModel.saveLocation()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertEqual(viewModel.saveStatus, .idle)
  }

  // MARK: - Geocoding Tests

  func testGeocodeAddress_WhenSuccessful_UpdatesCoordinates() async {
    // Given
    viewModel.location.city = "Springfield"
    viewModel.location.state = "IL"
    mockGeocoder.mockCoordinate = CLLocationCoordinate2D(latitude: 39.7817, longitude: -89.6501)

    // When
    await viewModel.geocodeAddress()

    // Then
    XCTAssertNotNil(viewModel.location.latitude)
    XCTAssertNotNil(viewModel.location.longitude)
    if let lat = viewModel.location.latitude, let lon = viewModel.location.longitude {
      XCTAssertEqual(lat, 39.7817, accuracy: 0.0001)
      XCTAssertEqual(lon, -89.6501, accuracy: 0.0001)
    }
    XCTAssertEqual(viewModel.saveStatus, .saving)
    XCTAssertFalse(viewModel.isGeocoding)
  }

  func testGeocodeAddress_WhenMissingCityOrState_ShowsError() async {
    // Given
    viewModel.location.city = nil
    viewModel.location.state = nil

    // When
    await viewModel.geocodeAddress()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertTrue(viewModel.errorMessage?.contains("city and state") ?? false)
  }

  func testGeocodeAddress_WhenGeocoderFails_ShowsError() async {
    // Given
    viewModel.location.city = "Springfield"
    viewModel.location.state = "IL"
    mockGeocoder.shouldFail = true

    // When
    await viewModel.geocodeAddress()

    // Then
    XCTAssertNotNil(viewModel.errorMessage)
    XCTAssertFalse(viewModel.isGeocoding)
  }

  // MARK: - Field Update Tests

  func testUpdateAddress_UpdatesLocation() {
    // When
    viewModel.updateAddress("123 Main St")

    // Then
    XCTAssertEqual(viewModel.location.address, "123 Main St")
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testUpdateAddress_WhenEmpty_SetsNil() {
    // When
    viewModel.updateAddress("")

    // Then
    XCTAssertNil(viewModel.location.address)
  }

  func testUpdateCity_UpdatesLocation() {
    // When
    viewModel.updateCity("Springfield")

    // Then
    XCTAssertEqual(viewModel.location.city, "Springfield")
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testUpdateState_ConvertsToUppercase() {
    // When
    viewModel.updateState("il")

    // Then
    XCTAssertEqual(viewModel.location.state, "IL")
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testUpdateState_LimitsToTwoCharacters() {
    // When
    viewModel.updateState("ILL")

    // Then
    XCTAssertEqual(viewModel.location.state, "IL")
  }

  func testUpdateZip_UpdatesLocation() {
    // When
    viewModel.updateZip("62701")

    // Then
    XCTAssertEqual(viewModel.location.zip, "62701")
    XCTAssertEqual(viewModel.saveStatus, .saving)
  }

  func testUpdateZip_LimitsToTenCharacters() {
    // When
    viewModel.updateZip("12345678901234")

    // Then
    XCTAssertEqual(viewModel.location.zip?.count, 10)
  }

  // MARK: - Computed Properties Tests

  func testHasCoordinates_WhenBothSet_ReturnsTrue() {
    // Given
    viewModel.location.latitude = 39.7817
    viewModel.location.longitude = -89.6501

    // Then
    XCTAssertTrue(viewModel.hasCoordinates)
  }

  func testHasCoordinates_WhenOnlyOneSet_ReturnsFalse() {
    // Given
    viewModel.location.latitude = 39.7817
    viewModel.location.longitude = nil

    // Then
    XCTAssertFalse(viewModel.hasCoordinates)
  }

  func testCoordinatesText_WhenSet_ReturnsFormattedString() {
    // Given
    viewModel.location.latitude = 39.7817
    viewModel.location.longitude = -89.6501

    // When
    let text = viewModel.coordinatesText

    // Then
    XCTAssertTrue(text.contains("39.7817"))
    XCTAssertTrue(text.contains("-89.6501"))
  }

  func testCoordinatesText_WhenNotSet_ReturnsPlaceholder() {
    // When
    let text = viewModel.coordinatesText

    // Then
    XCTAssertEqual(text, "No coordinates set")
  }
}

// MARK: - Mock Geocoder

final class MockGeocoder: CLGeocoder {
  var mockCoordinate: CLLocationCoordinate2D?
  var shouldFail = false

  override func geocodeAddressString(_ addressString: String) async throws -> [CLPlacemark] {
    if shouldFail {
      throw NSError(domain: "test", code: 1, userInfo: nil)
    }

    guard let coordinate = mockCoordinate else {
      return []
    }

    _ = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    let placemark = MKPlacemark(coordinate: coordinate)

    // Create a mock CLPlacemark with the location
    return [placemark]
  }
}

// Helper for creating CLPlacemark
import MapKit
